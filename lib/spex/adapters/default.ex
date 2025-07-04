defmodule Spex.Adapters.Default do
  @moduledoc """
  Default adapter for spex execution.

  Provides basic functionality without external dependencies.
  """

  @doc """
  Sets up the default adapter environment.
  """
  def setup do
    :ok
  end

  @doc """
  Takes a screenshot (no-op in default adapter).
  """
  def take_screenshot(filename \\ nil) do
    actual_filename = filename || "spex_screenshot_#{:os.system_time(:millisecond)}"
    full_path = "#{actual_filename}.png"
    
    # Create a placeholder file
    File.write!(full_path, "Default adapter placeholder screenshot - #{DateTime.utc_now()}")
    
    {:ok, %{filename: full_path, message: "Placeholder screenshot created"}}
  end

  @doc """
  Checks if application is running (always returns true in default adapter).
  """
  def app_running?(_port \\ 9999) do
    true
  end

  @doc """
  Waits for application to be ready (no-op in default adapter).
  """
  def wait_for_app(_port \\ 9999, _retries \\ 10) do
    true
  end
end