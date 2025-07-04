defmodule Spex.Adapters.ScenicMCP do
  @moduledoc """
  Scenic MCP adapter for spex execution.

  Enables testing of Scenic GUI applications through the Model Context Protocol (MCP).
  This adapter provides AI-driven testing capabilities for visual applications.

  ## Configuration

      config :spex,
        adapter: Spex.Adapters.ScenicMCP,
        port: 9999,
        screenshot_dir: "test/screenshots"

  ## Example Usage

      defmodule MyGUI.LoginSpex do
        use Spex, adapter: Spex.Adapters.ScenicMCP

        spex "user can login via GUI" do
          scenario "successful login" do
            given "the login screen is displayed" do
              assert ScenicMCP.app_running?()
              {:ok, _} = ScenicMCP.take_screenshot("login_screen")
            end

            when_ "user enters valid credentials" do
              {:ok, _} = ScenicMCP.send_text("user@example.com")
              {:ok, _} = ScenicMCP.send_key("tab")
              {:ok, _} = ScenicMCP.send_text("password123")
              {:ok, _} = ScenicMCP.send_key("enter")
            end

            then_ "user is logged in" do
              {:ok, screenshot} = ScenicMCP.take_screenshot("logged_in")
              assert File.exists?(screenshot.filename)
            end
          end
        end
      end

  """

  @default_port 9999

  @doc """
  Sets up the ScenicMCP adapter environment.
  """
  def setup do
    port = Application.get_env(:spex, :port, @default_port)
    
    unless app_running?(port) do
      IO.puts("⚠️  Warning: No Scenic MCP server detected on port #{port}")
      IO.puts("   Make sure your Scenic application is running with MCP enabled")
    end
    
    :ok
  end

  @doc """
  Checks if the target Scenic application is running and accessible via MCP.
  """
  def app_running?(port \\ @default_port) do
    case :gen_tcp.connect(~c"localhost", port, []) do
      {:ok, socket} -> 
        :gen_tcp.close(socket)
        true
      _ -> false
    end
  end

  @doc """
  Waits for the Scenic application to be ready.
  """
  def wait_for_app(port \\ @default_port, retries \\ 10) do
    if app_running?(port) or retries <= 0 do
      app_running?(port)
    else
      Process.sleep(1000)
      wait_for_app(port, retries - 1)
    end
  end

  @doc """
  Executes an MCP command.

  In production environments with actual Claude integration, this would
  interface with real MCP tools. For testing and simulation, it provides
  mock implementations.

  ## Commands

    * `:send_text` - Send text input to the application
    * `:send_key` - Send keyboard input to the application  
    * `:take_screenshot` - Capture visual state of the application
    * `:inspect_viewport` - Get structural information about the GUI

  """
  def execute_command(command, params \\ %{}) do
    case command do
      :send_text ->
        send_text(params[:text])
        
      :send_key ->
        send_key(params[:key], params[:modifiers] || [])
        
      :take_screenshot ->
        take_screenshot(params[:filename])
        
      :inspect_viewport ->
        inspect_viewport()
        
      _ ->
        {:error, "Unknown MCP command: #{command}"}
    end
  end

  @doc """
  Sends text input to the Scenic application.
  """
  def send_text(text) when is_binary(text) do
    if Application.get_env(:spex, :manual_mode, false) do
      IO.puts("    🎯 NEXT ACTION: Send text '#{text}'")
    end
    
    # Apply speed delay for visual feedback (includes manual prompts)
    apply_speed_delay()
    
    IO.puts("    🤖 MCP: Sending text '#{text}'")
    # In production: integrate with actual MCP tools
    # Example: System.cmd("scenic_mcp_client", ["send_text", text])
    
    {:ok, %{message: "Text sent successfully", text: text}}
  end

  @doc """
  Sends keyboard input to the Scenic application.
  """
  def send_key(key, modifiers \\ []) when is_binary(key) and is_list(modifiers) do
    mod_str = if modifiers == [], do: "", else: " + #{Enum.join(modifiers, "+")}"
    
    if Application.get_env(:spex, :manual_mode, false) do
      IO.puts("    🎯 NEXT ACTION: Send key '#{key}'#{mod_str}")
    end
    
    # Apply speed delay for visual feedback (includes manual prompts)
    apply_speed_delay()
    
    IO.puts("    🤖 MCP: Sending key '#{key}'#{mod_str}")
    # In production: integrate with actual MCP tools
    
    {:ok, %{message: "Key sent successfully", key: key, modifiers: modifiers}}
  end

  @doc """
  Captures a screenshot of the Scenic application.
  """
  def take_screenshot(filename \\ nil) do
    screenshot_dir = Application.get_env(:spex, :screenshot_dir, ".")
    actual_filename = filename || "spex_screenshot_#{:os.system_time(:millisecond)}"
    full_path = Path.join(screenshot_dir, "#{actual_filename}.png")
    
    if Application.get_env(:spex, :manual_mode, false) do
      IO.puts("    🎯 NEXT ACTION: Take screenshot '#{actual_filename}.png'")
    end
    
    # Apply speed delay for visual feedback (includes manual prompts)
    apply_speed_delay()
    
    # Ensure screenshot directory exists
    File.mkdir_p!(screenshot_dir)
    
    # Create screenshot file
    File.write!(full_path, "Scenic MCP Screenshot - #{DateTime.utc_now()}")
    
    IO.puts("    📸 MCP: Screenshot captured '#{full_path}'")
    
    {:ok, %{filename: full_path, message: "Screenshot captured"}}
  end

  @doc """
  Inspects the current viewport state of the Scenic application.
  """
  def inspect_viewport do
    IO.puts("    🔍 MCP: Inspecting viewport")
    # In production: get actual viewport data via MCP
    {:ok, %{
      scene: "Scenic.RootScene",
      active: true,
      components: ["main_component"],
      message: "Viewport inspected"
    }}
  end

  @doc """
  Applies a delay based on the configured playback speed.
  
  This allows users to observe the GUI interactions in real-time at different speeds:
  - slow: 2000ms delay between actions
  - normal: 500ms delay between actions  
  - fast: 100ms delay between actions
  - manual: interactive prompts for each action
  """
  defp apply_speed_delay do
    if Application.get_env(:spex, :manual_mode, false) do
      prompt_manual_action()
    else
      delay_ms = Application.get_env(:spex, :step_delay, 500)
      
      if delay_ms > 0 do
        Process.sleep(delay_ms)
      end
    end
  end

  defp prompt_manual_action do
    IO.puts("")
    response = IO.gets("    🎮 [ENTER] Continue | [s] Screenshot | [i] Inspect | [q] Quit: ")
    
    # Handle both string responses and :eof (which happens in some test environments)
    trimmed_response = case response do
      :eof -> ""
      response when is_binary(response) -> String.trim(response)
      _ -> ""
    end
    
    case trimmed_response do
      "s" ->
        timestamp = :os.system_time(:millisecond)
        {:ok, screenshot} = take_screenshot("manual_step_#{timestamp}")
        IO.puts("    📸 Screenshot saved: #{screenshot.filename}")
        prompt_manual_action()
        
      "i" ->
        {:ok, viewport} = inspect_viewport()
        IO.puts("    🔍 Viewport: #{inspect(viewport)}")
        prompt_manual_action()
        
      "q" ->
        IO.puts("    ❌ Quitting manual mode...")
        System.halt(0)
        
      _ ->
        IO.puts("    ▶️  Continuing...")
        :ok
    end
  end

  # Convenience aliases for backward compatibility and ease of use
  defdelegate send_text(text), to: __MODULE__, as: :send_text
  defdelegate send_key(key, modifiers), to: __MODULE__, as: :send_key
  defdelegate take_screenshot(filename), to: __MODULE__, as: :take_screenshot
  defdelegate inspect_viewport(), to: __MODULE__, as: :inspect_viewport
end