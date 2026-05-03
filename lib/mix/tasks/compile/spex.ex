defmodule Mix.Tasks.Compile.Spex do
  use Mix.Task.Compiler

  @moduledoc """
  Compiles `.exs` spex files and enforces boundary constraints.

  This compiler ensures that spex (executable specification) files respect
  module boundaries defined in the host application. When combined with
  the `boundary` library, it prevents spex tests from "reaching in" to
  application internals — enforcing true outside-in, black-box testing.

  ## Why This Exists

  Normally, `.exs` files are not checked by Boundary because they aren't
  part of the standard compilation pipeline. This compiler:

  1. Compiles spex files through `Kernel.ParallelCompiler`
  2. Re-attaches Boundary's tracer so cross-module references are tracked
  3. Runs Boundary's validation against those references
  4. Reports violations as compiler diagnostics

  The result: if a spex file tries to call an internal module directly
  (instead of going through the approved public interface like ScenicMCP),
  you get a clear compiler warning.

  ## Setup

  Add both `:boundary` and `:spex` to your project's compilers list.
  The `:boundary` compiler must come before `:elixir` so its tracer
  captures module references, and `:spex` must come after `:app`:

      def project do
        [
          compilers: [:boundary] ++ Mix.compilers() ++ [:spex],
          ...
        ]
      end

  Configure the glob pattern and boundary under the `:spex` key:

      def project do
        [
          spex: [
            pattern: "test/spex/**/*_spex.exs",
            boundary: MyApp.Spex
          ],
          ...
        ]
      end

  The `:boundary` option forces all spex modules into a specific boundary,
  regardless of their module name. This is the key mechanism for black-box
  enforcement — define a boundary that can only depend on your testing
  interface (e.g., ScenicMcp) and all spex modules will be confined to it.

  ## Example Boundary Setup

  In your application, define the spex boundary:

      # lib/my_app/spex.ex
      defmodule MyApp.Spex do
        use Boundary, deps: [ScenicMcp], exports: []
      end

  Any spex file that tries to call `MyApp.SomeInternalModule` directly
  will produce a boundary violation warning at compile time.

  ## Flags

    * `--spex-pattern` (`-p`) — glob pattern for .exs files to compile
  """

  @opts [
    strict: [spex_pattern: :string],
    aliases: [p: :spex_pattern]
  ]

  @impl true
  def run(argv) do
    if Mix.env() != :test do
      {:noop, []}
    else
      do_run(argv)
    end
  end

  defp do_run(argv) do
    {args, _, _} = OptionParser.parse(argv, @opts)
    config = Keyword.get(Mix.Project.config(), :spex, [])

    pattern =
      Keyword.get(args, :spex_pattern, Keyword.get(config, :pattern))

    boundary_override = Keyword.get(config, :boundary)

    result =
      if is_nil(pattern) do
        {:noop, []}
      else
        compile_exs_files(pattern, boundary_override)
      end

    {status, diags} = result
    :persistent_term.put({__MODULE__, :diagnostics}, diags)
    {status, diags}
  end

  @impl true
  def diagnostics do
    :persistent_term.get({__MODULE__, :diagnostics}, [])
  end

  defp compile_exs_files(pattern, boundary_override) do
    files = Path.wildcard(pattern)

    if Enum.empty?(files) do
      {:noop, []}
    else
      Mix.Task.run("loadpaths")

      # Boundary (and similar tracers) unregister themselves after :elixir finishes.
      # We temporarily re-add them so spex files get boundary-checked too.
      original_tracers = Code.get_compiler_option(:tracers)
      tracers = add_known_tracers(original_tracers)

      # Re-initialize Boundary's CompilerState if available.
      # The ETS table gets cleaned up after the main :elixir compiler finishes,
      # so we need to re-initialize it before compiling spex files.
      ensure_boundary_state_initialized()

      Code.put_compiler_option(:tracers, tracers)

      result =
        case Kernel.ParallelCompiler.compile(files,
               return_diagnostics: true,
               tracers: tracers
             ) do
          {:ok, modules, %{compile_warnings: warnings}} ->
            compile_diags = normalize_diagnostics(warnings)
            boundary_diags = run_boundary_check(modules, boundary_override)
            {:ok, compile_diags ++ boundary_diags}

          {:error, errors, %{compile_warnings: warnings}} ->
            {:error, normalize_diagnostics(errors ++ warnings)}
        end

      Code.put_compiler_option(:tracers, original_tracers)

      result
    end
  end

  defp ensure_boundary_state_initialized do
    state_mod = Boundary.Mix.CompilerState

    if Code.ensure_loaded?(state_mod) and function_exported?(state_mod, :start_link, 1) do
      state_mod.start_link([])
    end
  rescue
    _ -> :ok
  end

  # ---------------------------------------------------------------------------
  # Boundary integration
  #
  # After compiling spex files, we check them against the project's boundary
  # definitions. Spex modules are classified into a configured boundary
  # (or auto-classified by module name prefix), then Boundary.errors/2
  # checks for any forbidden cross-boundary references.
  # ---------------------------------------------------------------------------

  @boundary_tracer Mix.Tasks.Compile.Boundary

  defp run_boundary_check(compiled_modules, boundary_override) do
    boundary_mod = Boundary
    view_mod = Boundary.Mix.View
    state_mod = Boundary.Mix.CompilerState

    with true <- Code.ensure_loaded?(boundary_mod),
         true <- Code.ensure_loaded?(view_mod),
         true <- Code.ensure_loaded?(state_mod),
         true <- function_exported?(boundary_mod, :errors, 2),
         true <- function_exported?(view_mod, :build, 0),
         true <- function_exported?(state_mod, :references, 0) do
      spex_module_set = MapSet.new(compiled_modules)

      spex_refs =
        state_mod.references()
        |> Enum.filter(&MapSet.member?(spex_module_set, &1.from))

      if Enum.empty?(spex_refs) do
        []
      else
        apply(Boundary.Mix, :load_app, [])
        view = view_mod.build()
        view = classify_spex_modules(view, compiled_modules, boundary_override)

        boundary_mod.errors(view, spex_refs)
        |> Enum.filter(fn
          {:invalid_reference, _} -> true
          _ -> false
        end)
        |> Enum.map(&boundary_error_to_diagnostic/1)
        |> Enum.sort_by(&{&1.file, &1.position})
        |> tap(&print_diagnostics/1)
      end
    else
      _ -> []
    end
  rescue
    _ -> []
  end

  defp classify_spex_modules(view, spex_modules, boundary_override) do
    boundaries = view.classifier.boundaries
    main_app = view.main_app

    new_module_mappings =
      if boundary_override && Map.has_key?(boundaries, boundary_override) do
        # Force all spex modules into the configured boundary.
        # This is the key mechanism for black-box enforcement — spex modules
        # can only reference what this boundary's deps allow.
        for module <- spex_modules, into: %{}, do: {module, boundary_override}
      else
        # Fall back to auto-classification by module name prefix
        for module <- spex_modules,
            boundary_name = find_boundary_for_module(module, boundaries),
            boundary_name != nil,
            into: %{},
            do: {module, boundary_name}
      end

    new_module_to_app =
      for module <- spex_modules, into: %{}, do: {module, main_app}

    view
    |> update_in([:classifier, :modules], &Map.merge(&1, new_module_mappings))
    |> update_in([:module_to_app], &Map.merge(&1, new_module_to_app))
  end

  defp find_boundary_for_module(module, boundaries) do
    parts = Module.split(module)

    Enum.reduce_while(length(parts)..1//-1, nil, fn len, _acc ->
      candidate = parts |> Enum.take(len) |> Module.concat()

      if Map.has_key?(boundaries, candidate) do
        {:halt, candidate}
      else
        {:cont, nil}
      end
    end)
  end

  defp boundary_error_to_diagnostic({:invalid_reference, error}) do
    reason =
      case error.type do
        :normal ->
          "(references from #{inspect(error.from_boundary)} to #{inspect(error.to_boundary)} are not allowed)"

        :runtime ->
          "(runtime references from #{inspect(error.from_boundary)} to #{inspect(error.to_boundary)} are not allowed)"

        :not_exported ->
          "(module #{inspect(error.reference.to)} is not exported by its owner boundary #{inspect(error.to_boundary)})"

        :invalid_external_dep_call ->
          "(references from #{inspect(error.from_boundary)} to #{inspect(error.to_boundary)} are not allowed)"
      end

    %Mix.Task.Compiler.Diagnostic{
      compiler_name: "boundary",
      file: Path.relative_to_cwd(error.reference.file),
      message: "forbidden reference to #{inspect(error.reference.to)}\n  #{reason}",
      position: error.reference.line,
      severity: :warning,
      details: nil
    }
  end

  defp print_diagnostics([]), do: :ok

  defp print_diagnostics(diagnostics) do
    Mix.shell().info("")

    Enum.each(diagnostics, fn diag ->
      color = if diag.severity == :error, do: :red, else: :yellow
      pos = if is_integer(diag.position), do: ":#{diag.position}", else: ""
      location = if diag.file, do: "\n  #{diag.file}#{pos}\n", else: "\n"
      Mix.shell().info([:bright, color, "#{diag.severity}: ", :reset, diag.message, location])
    end)
  end

  defp add_known_tracers(existing) do
    if Code.ensure_loaded?(@boundary_tracer) and @boundary_tracer not in existing do
      [@boundary_tracer | existing]
    else
      existing
    end
  end

  defp normalize_diagnostics(diagnostics) do
    Enum.map(diagnostics, fn diag ->
      %Mix.Task.Compiler.Diagnostic{
        file: diag.file,
        position: diag.position,
        message: diag.message,
        severity: diag.severity,
        compiler_name: Map.get(diag, :compiler_name, "Spex"),
        details: Map.get(diag, :stacktrace)
      }
    end)
  end
end
