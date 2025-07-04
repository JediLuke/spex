defmodule Spex.ScenicMCP do
  @moduledoc """
  Scenic MCP integration helpers for Spex tests.
  
  Provides a clean interface for AI to interact with Scenic applications
  through the MCP (Model Context Protocol) bridge.
  """
  
  @doc "Check if the target application is running and accessible"
  def app_running?(port \\ 9999) do
    case :gen_tcp.connect(~c"localhost", port, []) do
      {:ok, socket} -> 
        :gen_tcp.close(socket)
        true
      _ -> false
    end
  end
  
  @doc "Wait for application to be ready"
  def wait_for_app(port \\ 9999, retries \\ 10) do
    if app_running?(port) or retries <= 0 do
      app_running?(port)
    else
      Process.sleep(1000)
      wait_for_app(port, retries - 1)
    end
  end
  
  @doc """
  Execute a scenic_mcp command.
  
  In production, this would interface with actual Claude MCP tools.
  For now, provides simulation interface.
  """
  def execute_mcp_command(command, params \\ %{}) do
    case command do
      :send_text ->
        simulate_send_text(params[:text])
        
      :send_key ->
        simulate_send_key(params[:key], params[:modifiers] || [])
        
      :take_screenshot ->
        simulate_take_screenshot(params[:filename])
        
      :inspect_viewport ->
        simulate_inspect_viewport()
        
      _ ->
        {:error, "Unknown MCP command: #{command}"}
    end
  end
  
  # Simulation functions - replace with actual MCP calls in production
  defp simulate_send_text(text) do
    IO.puts("    🤖 MCP: Sending text '#{text}'")
    {:ok, %{message: "Text sent successfully", text: text}}
  end
  
  defp simulate_send_key(key, modifiers) do
    mod_str = if modifiers == [], do: "", else: " + #{Enum.join(modifiers, "+")}"
    IO.puts("    🤖 MCP: Sending key '#{key}'#{mod_str}")
    {:ok, %{message: "Key sent successfully", key: key, modifiers: modifiers}}
  end
  
  defp simulate_take_screenshot(filename) do
    actual_filename = filename || "spex_screenshot_#{:os.system_time(:millisecond)}"
    full_path = "#{actual_filename}.png"
    
    # Create actual file for evidence
    File.write!(full_path, "Spex screenshot evidence - #{DateTime.utc_now()}")
    
    IO.puts("    📸 MCP: Screenshot captured '#{full_path}'")
    {:ok, %{filename: full_path, message: "Screenshot captured"}}
  end
  
  defp simulate_inspect_viewport() do
    IO.puts("    🔍 MCP: Inspecting viewport")
    {:ok, %{
      scene: "Application.RootScene",
      active: true,
      components: ["main_component"],
      message: "Viewport inspected"
    }}
  end
end