defmodule Mix.Tasks.Spex do
  @shortdoc "Run executable specifications (spex)"
  @moduledoc """
  Run spex files - executable specifications for AI-driven development.

  SexySpex provides a framework for writing executable specifications that serve as
  both tests and living documentation, optimized for AI-driven development workflows.

  Each spex file manages its own application lifecycle using setup_all and setup blocks:
  - setup_all: Application startup and shutdown
  - setup: State reset between tests
  - Context passing between test steps
  - Integration with external tools (like ScenicMCP for GUI testing)

  ## Usage

      mix spex                    # Run all spex files
      mix spex path/to/file.exs   # Run specific spex file
      mix spex --help             # Show this help

  ## Options

      --pattern       File pattern to match (default: test/spex/**/*_spex.exs)
      --verbose       Show detailed spex Reporter output (quiet by default)
      --timeout       Test timeout in milliseconds (default: 60000)
      --manual        Interactive manual mode - step through each action
      --speed         Execution speed: fast (default), medium, slow
      --trace         Enable ExUnit trace mode (shows test execution details)
      --formatter     ExUnit formatter module (default: ExUnit.CLIFormatter)
                      Can be specified multiple times
      --jsonl [PATH]  Output failures as JSONL (default: spex_failures.jsonl)
      --stale         Only run spex files that have changed or reference changed modules
      --force         Force all spex files to run (use with --stale to reset)

  ## Examples

      mix spex
      mix spex test/spex/user_login_spex.exs
      mix spex --pattern "**/integration_*_spex.exs"
      mix spex --verbose
      mix spex --manual           # Interactive step-by-step mode
      mix spex --speed slow       # Slower automatic execution
      mix spex --speed medium --verbose  # Medium speed with detailed output
      mix spex --trace            # Show detailed test execution
      mix spex test/spex/file.exs --trace

  ## Configuration

  You can configure spex behavior in your config files:

      config :sexy_spex,
        manual_mode: false,
        step_delay: 0

  Application lifecycle is handled in individual spex files using setup_all blocks.

  ## Important: Test Environment Setup

  To ensure spex runs in the test environment with proper module compilation,
  add this to your project's mix.exs:

      def project do
        [
          # ... other config
          preferred_cli_env: [
            spex: :test
          ]
        ]
      end

  This ensures that `mix spex` always runs in the test environment and compiles
  modules with test-specific code paths (e.g., test/support directories).

  """

  use Mix.Task

  alias Mix.Compilers.Test, as: CT

  @default_pattern "test/spex/**/*_spex.exs"
  @default_timeout 60_000

  def run(args) do
    # Ensure we're running in test environment for spex
    # Note: This task should have preferred_cli_env set to :test in mix.exs
    # of projects using spex to ensure proper compilation

    # Compile the project to ensure test environment modules are loaded
    Mix.Task.run("compile")

    # Start the application like mix test does
    # This ensures all applications and their dependencies are started
    Mix.Task.run("app.start")

    # Pre-process args to handle --jsonl without value (convert to --jsonl=default)
    args = preprocess_jsonl_arg(args)

    {opts, files, _} = OptionParser.parse(args,
      switches: [
        only_spex: :boolean,
        pattern: :string,
        verbose: :boolean,
        timeout: :integer,
        help: :boolean,
        manual: :boolean,
        speed: :string,
        trace: :boolean,
        formatter: :keep,
        jsonl: :string,
        stale: :boolean,
        force: :boolean
      ],
      aliases: [
        h: :help,
        v: :verbose,
        m: :manual,
        s: :speed,
        t: :trace,
        f: :formatter,
        j: :jsonl
      ]
    )

    if opts[:help] do
      Mix.shell().info(@moduledoc)
      return()
    end

    # Find spex files
    spex_files = find_spex_files(files, opts)

    if Enum.empty?(spex_files) do
      pattern = opts[:pattern] || @default_pattern
      Mix.shell().info("No spex files found matching pattern: #{pattern}")
      Mix.shell().info("Try: mix spex --help")
      # Exit early if no files found
      System.halt(0)
    end

    # Configure spex execution
    configure_spex_mode(opts)

    if opts[:verbose] do
      Mix.shell().info("Running #{length(spex_files)} spex file(s)...")
    end

    # Run spex tests with ExUnit
    run_tests_with_exunit(spex_files, opts)
  end

  defp return, do: :ok

  # Handle --jsonl without a value: if the next arg looks like a file, don't consume it
  defp preprocess_jsonl_arg(args) do
    preprocess_jsonl_arg(args, [])
  end

  defp preprocess_jsonl_arg([], acc), do: Enum.reverse(acc)

  defp preprocess_jsonl_arg(["--jsonl" | rest], acc) do
    case rest do
      [next | remaining] when is_binary(next) ->
        # If next arg starts with - or ends with .exs, treat --jsonl as having default value
        if String.starts_with?(next, "-") or String.ends_with?(next, ".exs") do
          preprocess_jsonl_arg(rest, ["--jsonl=spex_failures.jsonl" | acc])
        else
          # Next arg is the jsonl path, skip it
          preprocess_jsonl_arg(remaining, ["--jsonl=#{next}" | acc])
        end
      [] ->
        # --jsonl at end with no value
        Enum.reverse(["--jsonl=spex_failures.jsonl" | acc])
    end
  end

  defp preprocess_jsonl_arg(["-j" | rest], acc) do
    preprocess_jsonl_arg(["--jsonl" | rest], acc)
  end

  defp preprocess_jsonl_arg([arg | rest], acc) do
    preprocess_jsonl_arg(rest, [arg | acc])
  end

  defp find_spex_files([], opts) do
    # No specific files provided, use pattern
    pattern = opts[:pattern] || @default_pattern
    Path.wildcard(pattern)
  end

  defp find_spex_files(files, _opts) do
    # Specific files provided
    Enum.filter(files, &File.exists?/1)
  end

  defp configure_spex_mode(opts) do
    # Quiet by default; verbose opts in
    unless opts[:verbose] do
      Application.put_env(:sexy_spex, :quiet, true)
    end

    # Configure JSONL output if requested
    if opts[:jsonl] do
      Application.put_env(:sexy_spex, :jsonl_enabled, true)
      path = if is_binary(opts[:jsonl]) and opts[:jsonl] != "true",
        do: opts[:jsonl],
        else: "spex_failures.jsonl"
      Application.put_env(:sexy_spex, :jsonl_path, path)
      # Clear file at start
      File.write!(path, "")
    end

    # Set manual mode if requested
    if opts[:manual] do
      Application.put_env(:sexy_spex, :manual_mode, true)
      Application.put_env(:sexy_spex, :step_delay, 0)
      if opts[:verbose], do: Mix.shell().info("Manual mode enabled - you'll be prompted at each step")
    else
      # Configure speed if provided
      configure_speed(opts[:speed], opts[:verbose])
    end
  end

  defp configure_speed(nil, verbose), do: configure_speed("fast", verbose)
  defp configure_speed("fast", _verbose) do
    Application.put_env(:sexy_spex, :step_delay, 0)
  end
  defp configure_speed("medium", verbose) do
    Application.put_env(:sexy_spex, :step_delay, 1000)
    if verbose, do: Mix.shell().info("Medium speed mode - 1s delays between steps")
  end
  defp configure_speed("slow", verbose) do
    Application.put_env(:sexy_spex, :step_delay, 2500)
    if verbose, do: Mix.shell().info("Slow speed mode - 2.5s delays between steps")
  end
  defp configure_speed(invalid, _verbose) do
    Mix.shell().error("Invalid speed: #{invalid}. Valid options: fast, medium, slow")
    System.halt(1)
  end

  defp parse_formatters(opts) do
    formatters =
      opts
      |> Keyword.get_values(:formatter)
      |> Enum.map(&parse_formatter_module/1)

    if Enum.empty?(formatters) do
      [ExUnit.CLIFormatter]
    else
      formatters
    end
  end

  defp parse_formatter_module(name) do
    module = Module.concat([name])

    unless Code.ensure_loaded?(module) do
      Mix.shell().error("Could not load formatter module: #{name}")
      System.halt(1)
    end

    module
  end

  defp run_tests_with_exunit(spex_files, opts) do
    if opts[:stale] do
      run_with_stale_tracking(spex_files, opts)
    else
      run_without_stale_tracking(spex_files, opts)
    end
  end

  defp run_without_stale_tracking(spex_files, opts) do
    opts
    |> build_exunit_config()
    |> ExUnit.start()

    load_spex_files(spex_files, opts)

    ExUnit.run()
    |> handle_results()
  end

  defp run_with_stale_tracking(spex_files, opts) do
    exunit_config = build_exunit_config(opts)
    ExUnit.start(exunit_config)

    test_paths = spex_test_paths()
    test_elixirc_options = Mix.Project.config()[:test_elixirc_options] || []

    case CT.require_and_run(spex_files, test_paths, test_elixirc_options, opts) do
      {:ok, results} ->
        handle_results(results)

      :noop ->
        if opts[:verbose] do
          Mix.shell().info("No stale spex files")
        end

        System.halt(0)
    end
  end

  defp spex_test_paths do
    # Return the directory containing spex files so the stale manifest
    # can find test_helper.exs (falls back gracefully if not present)
    ["test/spex"]
  end

  defp build_exunit_config(opts) do
    timeout = opts[:timeout] || @default_timeout
    formatters = parse_formatters(opts)

    config = [
      colors: [enabled: true],
      formatters: formatters,
      timeout: timeout
    ]

    config
    |> maybe_enable_trace(opts[:verbose])
    |> maybe_enable_trace(opts[:trace])
  end

  defp maybe_enable_trace(config, true), do: Keyword.put(config, :trace, true)
  defp maybe_enable_trace(config, _), do: config

  # When the :spex compiler (from client_utils) already compiled these files,
  # suppress "redefining module" warnings — we still need Code.require_file
  # so modules register with ExUnit.
  defp load_spex_files(spex_files, _opts) do
    already_compiled = spex_already_compiled?()
    if already_compiled, do: Code.put_compiler_option(:ignore_module_conflict, true)

    Enum.each(spex_files, fn file ->
      try do
        Code.require_file(file)
      rescue
        error ->
          Mix.shell().error("Failed to load #{file}: #{Exception.message(error)}")
          System.halt(1)
      end
    end)

    if already_compiled, do: Code.put_compiler_option(:ignore_module_conflict, false)
  end

  defp spex_already_compiled? do
    :persistent_term.get({Mix.Tasks.Compile.Spex, :diagnostics}, nil) != nil
  end

  defp handle_results(result) do
    verbose = !Application.get_env(:sexy_spex, :quiet, true)

    case result do
      %{failures: 0} ->
        if verbose, do: Mix.shell().info("All spex passed!")
        System.halt(0)

      %{failures: failures} when failures > 0 ->
        if verbose, do: Mix.shell().error("#{failures} spex failed")
        System.halt(1)

      _ ->
        if verbose, do: Mix.shell().error("Spex execution encountered errors")
        System.halt(1)
    end
  end

end
