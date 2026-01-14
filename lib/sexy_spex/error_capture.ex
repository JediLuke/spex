defmodule SexySpex.ErrorCapture do
  @moduledoc """
  Captures error logs during spex execution.

  This module provides a way to detect if any error logs were emitted during
  test execution, allowing spex to fail if errors occur even if no assertion failed.

  ## Usage

  In your spex file, enable error capture:

      use SexySpex, fail_on_error_logs: true

  Or start/stop manually:

      SexySpex.ErrorCapture.start()
      # ... run tests ...
      errors = SexySpex.ErrorCapture.get_errors()
      SexySpex.ErrorCapture.stop()

  ## How It Works

  Uses an ETS table to store captured errors and a custom Logger handler
  to intercept error-level log messages.
  """

  use GenServer
  require Logger

  @table_name :sexy_spex_error_capture
  @handler_id :sexy_spex_error_handler

  # ===== PUBLIC API =====

  @doc """
  Starts the error capture process and installs the Logger handler.
  """
  def start do
    case GenServer.start(__MODULE__, [], name: __MODULE__) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
    end
  end

  @doc """
  Stops the error capture process and removes the Logger handler.
  """
  def stop do
    if Process.whereis(__MODULE__) do
      GenServer.stop(__MODULE__)
    end
  end

  @doc """
  Clears all captured errors.
  """
  def clear do
    if :ets.whereis(@table_name) != :undefined do
      :ets.delete_all_objects(@table_name)
    end
    :ok
  end

  @doc """
  Returns all captured errors.
  """
  def get_errors do
    if :ets.whereis(@table_name) != :undefined do
      :ets.tab2list(@table_name)
      |> Enum.map(fn {_key, error} -> error end)
      |> Enum.sort_by(fn error -> error.timestamp end)
    else
      []
    end
  end

  @doc """
  Returns true if any errors were captured.
  """
  def has_errors? do
    length(get_errors()) > 0
  end

  @doc """
  Returns error count.
  """
  def error_count do
    length(get_errors())
  end

  @doc """
  Formats captured errors for display.
  """
  def format_errors do
    errors = get_errors()
    if length(errors) == 0 do
      nil
    else
      header = "\n❌ #{length(errors)} error(s) logged during test execution:\n"
      error_lines = Enum.map(errors, fn error ->
        "  • [#{error.level}] #{error.message}"
      end)
      header <> Enum.join(error_lines, "\n")
    end
  end

  @doc """
  Checks for errors and raises if any were found.
  """
  def check_and_raise! do
    if has_errors?() do
      message = format_errors()
      clear()  # Clear after reporting
      raise ExUnit.AssertionError, message: message
    end
  end

  # ===== GENSERVER CALLBACKS =====

  @impl true
  def init([]) do
    # Create ETS table for storing errors
    :ets.new(@table_name, [:named_table, :public, :set])

    # Add Logger handler (Elixir 1.15+ uses :logger module)
    :logger.add_handler(@handler_id, __MODULE__.Handler, %{})

    {:ok, %{}}
  end

  @impl true
  def terminate(_reason, _state) do
    # Remove Logger handler
    :logger.remove_handler(@handler_id)

    # Delete ETS table
    if :ets.whereis(@table_name) != :undefined do
      :ets.delete(@table_name)
    end

    :ok
  end

  # ===== LOGGER HANDLER =====

  defmodule Handler do
    @moduledoc false

    @table_name :sexy_spex_error_capture

    @doc """
    Logger handler callback - captures error-level messages.
    """
    def log(%{level: level, msg: msg, meta: meta}, _config) when level in [:error, :emergency, :alert, :critical] do
      message = format_message(msg)

      error = %{
        level: level,
        message: message,
        timestamp: System.system_time(:millisecond),
        meta: meta
      }

      key = System.unique_integer([:positive])

      if :ets.whereis(@table_name) != :undefined do
        :ets.insert(@table_name, {key, error})
      end

      :ok
    end

    def log(_event, _config), do: :ok

    defp format_message({:string, msg}), do: IO.iodata_to_binary(msg)
    defp format_message({:report, report}), do: inspect(report)
    defp format_message(msg) when is_binary(msg), do: msg
    defp format_message(msg), do: inspect(msg)
  end
end
