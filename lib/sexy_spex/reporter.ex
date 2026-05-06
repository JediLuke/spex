defmodule SexySpex.Reporter do
  @moduledoc """
  Handles reporting and output formatting for spex execution.

  Provides a clean interface for tracking spex execution progress and
  generating human-readable output.

  ## Quiet Mode (Default)

  Reporter output is suppressed by default. Use `--verbose` flag to enable
  detailed Reporter output alongside ExUnit results.

  ## JSONL Output

  Use `--jsonl` flag to output test failures as JSONL for machine parsing.
  Each failure includes BDD step context (Given/When/Then) alongside error info.
  """

  @state_key :sexy_spex_reporter_state

  defp quiet? do
    Application.get_env(:sexy_spex, :quiet, true)
  end

  defp jsonl_enabled? do
    Application.get_env(:sexy_spex, :jsonl_enabled, false)
  end

  # State management using process dictionary
  defp init_state(spex_name) do
    Process.put(@state_key, %{spex: spex_name, scenario: nil, steps: [], jsonl_written: false})
  end

  defp mark_jsonl_written do
    state = Process.get(@state_key, %{})
    Process.put(@state_key, Map.put(state, :jsonl_written, true))
  end

  defp jsonl_already_written? do
    state = Process.get(@state_key, %{})
    Map.get(state, :jsonl_written, false)
  end

  defp set_scenario_state(name) do
    state = Process.get(@state_key, %{})
    Process.put(@state_key, %{state | scenario: name, steps: []})
  end

  defp add_step(type, description) do
    state = Process.get(@state_key, %{})
    step = %{type: type, description: to_string(description), status: "passed"}
    Process.put(@state_key, %{state | steps: state.steps ++ [step]})
  end

  defp mark_last_step_failed do
    state = Process.get(@state_key, %{})
    case state.steps do
      [] -> :ok
      steps ->
        updated = List.update_at(steps, -1, &Map.put(&1, :status, "failed"))
        Process.put(@state_key, %{state | steps: updated})
    end
  end

  defp get_state, do: Process.get(@state_key, %{})
  defp clear_state, do: Process.delete(@state_key)

  @doc """
  Starts reporting for a new specification.
  """
  def start_spex(name, opts \\ []) do
    init_state(name)

    unless quiet?() do
      IO.puts("")
      IO.puts("🎯 Running Spex: #{name}")
      IO.puts(String.duplicate("=", 50))

      if description = opts[:description] do
        IO.puts("   #{description}")
      end

      if tags = opts[:tags] do
        tag_str = tags |> Enum.map(&"##{&1}") |> Enum.join(" ")
        IO.puts("   Tags: #{tag_str}")
      end

      IO.puts("")
    end
  end

  @doc """
  Reports successful completion of a specification.
  """
  def spex_passed(name) do
    unless quiet?() do
      IO.puts("")
      IO.puts("✅ Spex completed: #{name}")
    end

    clear_state()
  end

  @doc """
  Reports failure of a specification.
  """
  def spex_failed(name, error, stacktrace \\ []) do
    mark_last_step_failed()

    if jsonl_enabled?() and not jsonl_already_written?() do
      write_jsonl_failure(error, stacktrace)
    end

    unless quiet?() do
      IO.puts("")
      IO.puts("❌ Spex failed: #{name}")
      IO.puts("   Error: #{format_error(error)}")
    end

    clear_state()
  end

  # Handle exception structs
  defp format_error(%{__exception__: true} = exception) do
    Exception.message(exception)
  end

  # Handle plain maps with :message key (from error capture)
  defp format_error(%{message: message}) when is_binary(message) do
    message
  end

  # Fallback for any other value
  defp format_error(other) do
    inspect(other)
  end

  @doc """
  Starts reporting for a new scenario.
  """
  def start_scenario(name) do
    set_scenario_state(name)
    unless quiet?(), do: IO.puts("  📋 Scenario: #{name}")
  end

  @doc """
  Reports successful completion of a scenario.
  """
  def scenario_passed(name) do
    unless quiet?() do
      IO.puts("  ✅ Scenario passed: #{name}")
      IO.puts("")
    end
  end

  @doc """
  Reports failure of a scenario.
  """
  def scenario_failed(name, error, stacktrace \\ []) do
    mark_last_step_failed()

    if jsonl_enabled?() and not jsonl_already_written?() do
      write_jsonl_failure(error, stacktrace)
      mark_jsonl_written()
    end

    unless quiet?() do
      IO.puts("  ❌ Scenario failed: #{name}")
      IO.puts("     Error: #{format_error(error)}")
      IO.puts("")
    end
  end

  @doc """
  Reports execution of a Given-When-Then step.
  """
  def step(type, description) do
    add_step(type, description)
    unless quiet?(), do: IO.puts("    #{type}: #{description}")
  end

  # JSONL output functions

  defp write_jsonl_failure(error, stacktrace) do
    state = get_state()

    failure = %{
      type: "failure",
      spex: state[:spex],
      scenario: state[:scenario],
      steps: state[:steps] || [],
      error: format_error_for_jsonl(error, stacktrace)
    }

    path = Application.get_env(:sexy_spex, :jsonl_path, "spex_failures.jsonl")
    json = Jason.encode!(failure)
    File.write!(path, json <> "\n", [:append])
  end

  defp format_error_for_jsonl(error, stacktrace) do
    {file, line} = extract_location(stacktrace)

    base = %{
      message: format_error(error),
      file: file,
      line: line,
      stacktrace: format_stacktrace_for_jsonl(stacktrace)
    }

    case error do
      %ExUnit.AssertionError{left: left, right: right} ->
        base
        |> maybe_put(:left, left)
        |> maybe_put(:right, right)
      _ -> base
    end
  end

  defp extract_location([]) do
    {nil, nil}
  end

  defp extract_location(stacktrace) do
    # Find the first stack entry that looks like a test file
    entry = Enum.find(stacktrace, fn
      {_mod, _fun, _arity, opts} ->
        file = Keyword.get(opts, :file, "")
        String.contains?(to_string(file), "_spex.exs") or
          String.contains?(to_string(file), "_test.exs")
      _ -> false
    end)

    case entry do
      {_mod, _fun, _arity, opts} ->
        {to_string(Keyword.get(opts, :file)), Keyword.get(opts, :line)}
      _ ->
        # Fallback to first entry with file info
        case List.first(stacktrace) do
          {_mod, _fun, _arity, opts} ->
            {to_string(Keyword.get(opts, :file)), Keyword.get(opts, :line)}
          _ ->
            {nil, nil}
        end
    end
  end

  defp format_stacktrace_for_jsonl(stacktrace) do
    Enum.map(stacktrace, fn
      {mod, fun, arity, opts} when is_integer(arity) ->
        %{
          module: inspect(mod),
          function: to_string(fun),
          arity: arity,
          file: to_string(Keyword.get(opts, :file, "")),
          line: Keyword.get(opts, :line)
        }
      {mod, fun, args, opts} when is_list(args) ->
        %{
          module: inspect(mod),
          function: to_string(fun),
          arity: length(args),
          file: to_string(Keyword.get(opts, :file, "")),
          line: Keyword.get(opts, :line)
        }
      other ->
        %{raw: inspect(other)}
    end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, inspect(value))
end
