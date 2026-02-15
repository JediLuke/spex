defmodule SexySpex.StepExecutor do
  @moduledoc """
  Core step execution system for SexySpex.

  Handles stepping, manual mode, timing, and execution control across all adapters.
  This module provides framework-agnostic step control, allowing manual mode to work
  with any testing scenario (Scenic, Phoenix, libraries, etc.).
  """

  @doc """
  Executes a step with the configured execution mode.

  Supports:
  - Normal execution (immediate)
  - Timed execution (with delays)
  - Manual mode (step-by-step with user prompts)

  ## Parameters

    * `step_type` - The type of step ("Given", "When", "Then", "And")
    * `description` - Human-readable description of the step
    * `step_function` - The function to execute for this step (arity 0)

  ## Configuration

  Reads configuration from application environment:
  - `:sexy_spex, :manual_mode` - Boolean, enables manual stepping
  - `:sexy_spex, :step_delay` - Integer, delay in ms between steps
  - `:sexy_spex, :speed` - Atom, execution speed (:slow, :normal, :fast, :manual)
  """
  def execute_step(step_type, description, step_function) do
    # Check if manual mode is enabled
    manual_mode = Application.get_env(:sexy_spex, :manual_mode, false)

    if manual_mode do
      execute_manual_step(step_type, description, step_function)
    else
      execute_timed_step(step_type, description, step_function)
    end
  end

  @doc """
  Executes a step with context passed as argument (like ExUnit setup).

  ## Parameters

    * `step_type` - The type of step ("Given", "When", "Then", "And")
    * `description` - Human-readable description of the step
    * `context` - Current context map
    * `step_function` - Function that receives context and returns updated context
  """
  def execute_step(step_type, description, context, step_function) do
    manual_mode = Application.get_env(:sexy_spex, :manual_mode, false)

    if manual_mode do
      execute_manual_step_with_context(step_type, description, context, step_function)
    else
      execute_timed_step_with_context(step_type, description, context, step_function)
    end
  end

  # Executes a step in manual mode with user interaction.
  defp execute_manual_step(step_type, description, step_function) do
    IO.puts("")
    IO.puts("  🎯 NEXT STEP: #{step_type} #{description}")

    case prompt_manual_action() do
      :continue ->
        IO.puts("  ▶️  Executing step...")
        result = step_function.()
        IO.puts("  ✅ Step completed")
        result

      :quit ->
        IO.puts("  ❌ Quitting manual mode...")
        System.halt(0)
    end
  end

  # Executes a step with timing delays based on speed configuration.
  defp execute_timed_step(step_type, description, step_function) do
    # Apply pre-step delay if configured
    apply_step_delay()

    # Show step info for slow/medium speeds
    show_step_info(step_type, description)

    # Execute the step
    step_function.()
  end

  # Executes a step in manual mode with context passed as argument.
  defp execute_manual_step_with_context(step_type, description, context, step_function) do
    IO.puts("")
    IO.puts("  🎯 NEXT STEP: #{step_type} #{description}")

    case prompt_manual_action() do
      :continue ->
        IO.puts("  ▶️  Executing step...")
        result = step_function.(context)
        IO.puts("  ✅ Step completed")
        result

      :quit ->
        IO.puts("  ❌ Quitting manual mode...")
        System.halt(0)
    end
  end

  # Executes a step with context and timing delays.
  defp execute_timed_step_with_context(step_type, description, context, step_function) do
    apply_step_delay()
    show_step_info(step_type, description)
    step_function.(context)
  end

  # Prompts the user for the next action in manual mode.
  # Returns: `:continue` - Proceed with step execution, `:quit` - Exit the test run
  defp prompt_manual_action do
    response = IO.gets("  🎮 [ENTER] Continue | [iex] IEx Shell | [q] Quit: ")

    # Handle both string responses and :eof (which happens in some test environments)
    trimmed_response = case response do
      :eof -> ""
      response when is_binary(response) -> String.trim(response)
      _ -> ""
    end

    case trimmed_response do
      "iex" ->
        start_interactive_shell()
        prompt_manual_action()

      "q" ->
        :quit

      _ ->
        :continue
    end
  end

  # Shows step information for slower speeds
  defp show_step_info(step_type, description) do
    delay_ms = Application.get_env(:sexy_spex, :step_delay, 0)
    
    if delay_ms > 0 do
      IO.puts("  🎯 #{step_type} #{description}")
    end
  end

  # Applies step delay based on configured speed.
  defp apply_step_delay do
    delay_ms = Application.get_env(:sexy_spex, :step_delay, 0)

    if delay_ms > 0 do
      Process.sleep(delay_ms)
    end
  end

  # Starts an interactive shell for debugging between test steps.
  # User can inspect application state, call functions, take screenshots, etc.
  # Uses a simple evaluation loop that's easier to exit than full IEx.
  defp start_interactive_shell do
    IO.puts("")
    IO.puts("  🐚 Starting debug shell...")
    IO.puts("  💡 Tips:")
    IO.puts("     - SexySpex.Adapters.ScenicMCP.take_screenshot(\"debug\")")
    IO.puts("     - SexySpex.Adapters.ScenicMCP.inspect_viewport()")
    IO.puts("     - Application.started_applications()")
    IO.puts("     - Type 'exit' or 'quit' to return to test")
    IO.puts("")
    
    interactive_loop()
  end
  
  defp interactive_loop do
    input = IO.gets("🐚> ")
    
    case String.trim(input || "") do
      "" -> interactive_loop()
      "exit" -> 
        IO.puts("  🔄 Returning to test execution...")
        :ok
      "quit" -> 
        IO.puts("  🔄 Returning to test execution...")
        :ok
      code ->
        try do
          {result, _binding} = Code.eval_string(code)
          IO.puts("→ #{inspect(result)}")
        rescue
          error ->
            IO.puts("❌ Error: #{Exception.message(error)}")
        catch
          kind, error ->
            IO.puts("❌ #{kind}: #{inspect(error)}")
        end
        interactive_loop()
    end
  end
end
