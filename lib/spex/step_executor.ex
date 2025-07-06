defmodule Spex.StepExecutor do
  @moduledoc """
  Core step execution system for Spex.

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
    * `step_function` - The function to execute for this step

  ## Configuration

  Reads configuration from application environment:
  - `:spex, :manual_mode` - Boolean, enables manual stepping
  - `:spex, :step_delay` - Integer, delay in ms between steps
  - `:spex, :speed` - Atom, execution speed (:slow, :normal, :fast, :manual)
  """
  def execute_step(step_type, description, step_function) do
    # Check if manual mode is enabled
    manual_mode = Application.get_env(:spex, :manual_mode, false)

    if manual_mode do
      execute_manual_step(step_type, description, step_function)
    else
      execute_timed_step(step_type, description, step_function)
    end
  end

  @doc """
  Executes a step in manual mode with user interaction.
  """
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

  @doc """
  Executes a step with timing delays based on speed configuration.
  """
  defp execute_timed_step(step_type, description, step_function) do
    # Apply pre-step delay if configured
    apply_step_delay()

    # Execute the step
    step_function.()
  end

  @doc """
  Prompts the user for the next action in manual mode.

  Returns:
  - `:continue` - Proceed with step execution
  - `:quit` - Exit the test run
  """
  defp prompt_manual_action do
    response = IO.gets("  🎮 [ENTER] Continue | [s] Screenshot | [i] Inspect | [q] Quit: ")

    # Handle both string responses and :eof (which happens in some test environments)
    trimmed_response = case response do
      :eof -> ""
      response when is_binary(response) -> String.trim(response)
      _ -> ""
    end

    case trimmed_response do
      "s" ->
        take_screenshot_if_available()
        prompt_manual_action()

      "i" ->
        inspect_viewport_if_available()
        prompt_manual_action()

      "q" ->
        :quit

      _ ->
        :continue
    end
  end

  @doc """
  Applies step delay based on configured speed.
  """
  defp apply_step_delay do
    delay_ms = Application.get_env(:spex, :step_delay, 0)

    if delay_ms > 0 do
      Process.sleep(delay_ms)
    end
  end

end
