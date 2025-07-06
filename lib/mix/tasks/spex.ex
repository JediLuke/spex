defmodule Mix.Tasks.Spex do
  @shortdoc "Run executable specifications (spex) with GUI lifecycle management"
  @moduledoc """
  Run spex files - executable specifications for AI-driven development.

  Spex provides a framework for writing executable specifications that serve as
  both tests and living documentation, optimized for AI-driven development workflows.

  This task automatically manages the complete lifecycle:
  1. Starts the target application (e.g., Quillex)
  2. Waits for MCP server to be ready
  3. Runs spex tests with real-time visual feedback
  4. Provides playback speed control for test observation
  5. Captures logs and screenshots
  6. Cleans up resources when done

  ## Usage

      mix spex                    # Run all spex files
      mix spex path/to/file.exs   # Run specific spex file
      mix spex --help             # Show this help

  ## Options

      --only-spex     Run only spex tests (skip regular ExUnit tests)
      --pattern       File pattern to match (default: test/spex/**/*_spex.exs)
      --verbose       Show detailed output
      --timeout       Test timeout in milliseconds (default: 60000)
      --speed         Playback speed (slow/normal/fast/manual) (default: normal)
      --sequential    Run tests one at a time (default: true)
      --watch         Watch mode - keep GUI open for observation
      --manual        Interactive manual mode - step through each action
      --app-path      Path to the application to start (default: current directory)
      --port          MCP server port (default: 9999)

  ## Examples

      mix spex
      mix spex test/spex/user_login_spex.exs
      mix spex --pattern "**/integration_*_spex.exs"
      mix spex --only-spex --verbose --speed slow
      mix spex --watch --speed fast
      mix spex --manual --verbose        # Interactive step-by-step mode
      mix spex --speed manual            # Also activates manual mode
      mix spex --app-path ../quillex --port 9999

  ## Configuration

  You can configure spex behavior in your config files:

      config :spex,
        adapter: Spex.Adapters.ScenicMCP,
        screenshot_dir: "test/screenshots",
        port: 9999,
        app_path: ".",
        speed: :normal

  """

  use Mix.Task

  @default_pattern "test/spex/**/*_spex.exs"
  @default_timeout 60_000
  @default_port 9999
  @default_speed :normal

  def run(args) do
    {opts, files, _} = OptionParser.parse(args,
      switches: [
        only_spex: :boolean,
        pattern: :string,
        verbose: :boolean,
        timeout: :integer,
        help: :boolean,
        speed: :string,
        sequential: :boolean,
        watch: :boolean,
        manual: :boolean,
        app_path: :string,
        port: :integer
      ],
      aliases: [
        h: :help,
        v: :verbose,
        s: :speed,
        w: :watch,
        m: :manual,
        p: :port
      ]
    )

    if opts[:help] do
      Mix.shell().info(@moduledoc)
      return()
    end

    # Setup configuration
    config = setup_config(opts)

    # Find and load spex files
    spex_files = find_spex_files(files, opts)

    if Enum.empty?(spex_files) do
      pattern = opts[:pattern] || @default_pattern
      Mix.shell().info("No spex files found matching pattern: #{pattern}")
      Mix.shell().info("Try: mix spex --help")
      return()
    end

    Mix.shell().info("🚀 Starting spex lifecycle management...")
    Mix.shell().info("   📁 App path: #{config.app_path}")
    Mix.shell().info("   🌐 Port: #{config.port}")
    Mix.shell().info("   ⚡ Speed: #{config.speed}")
    Mix.shell().info("   📝 Files: #{length(spex_files)}")

    # Start application lifecycle
    app_pid = start_application(config)

    try do
      # Wait for MCP server to be ready
      wait_for_mcp_server(config)

      # Setup screenshot directory
      setup_screenshot_dir(config)

      # Manual mode initial prompt
      if config.manual do
        prompt_manual_start(config)
      end

      # Configure ExUnit for spex
      configure_exunit(opts, config)

      # Load spex files
      load_spex_files(spex_files, config)

      # Run the tests
      results = run_spex_tests(spex_files, config)

      # Handle results
      handle_results(results, config)

    after
      # Cleanup
      cleanup_application(app_pid, config)
    end
  end

  defp return, do: :ok

  defp setup_config(opts) do
    app_path = opts[:app_path] || Application.get_env(:spex, :app_path, ".")
    port = opts[:port] || Application.get_env(:spex, :port, @default_port)
    speed = parse_speed(opts[:speed]) || Application.get_env(:spex, :speed, @default_speed)
    screenshot_dir = Application.get_env(:spex, :screenshot_dir, "test/screenshots")

    # Manual mode can be activated by --manual flag OR --speed manual
    manual_mode = opts[:manual] || speed == :manual

    %{
      app_path: Path.expand(app_path),
      port: port,
      speed: if(manual_mode, do: :manual, else: speed),
      screenshot_dir: screenshot_dir,
      sequential: opts[:sequential] != false,  # Default to true
      watch: opts[:watch] || false,
      verbose: opts[:verbose] || false,
      timeout: opts[:timeout] || @default_timeout,
      manual: manual_mode
    }
  end

  defp parse_speed(nil), do: @default_speed
  defp parse_speed("slow"), do: :slow
  defp parse_speed("normal"), do: :normal
  defp parse_speed("fast"), do: :fast
  defp parse_speed("manual"), do: :manual
  defp parse_speed(_), do: @default_speed

  defp start_application(config) do
    Mix.shell().info("🚀 Starting application at #{config.app_path}...")
    Mix.shell().info("   🔧 Current Mix.env: #{Mix.env()}")

    # Kill any existing process on the port
    cleanup_existing_process(config.port)

    # Use the same approach as mix test - this is the key!
    # mix test calls Mix.Task.run("app.start") which properly handles all dependencies

    # First ensure we're in the right app directory
    original_dir = File.cwd!()
    File.cd!(config.app_path)

    # For spex, we want to start quillex WITH GUI for full visual testing
    # The dependency issues are now resolved with Mix.Task.run("app.start")
    Application.put_env(:quillex, :started_by_flamelex?, false)
    # Mix.shell().info("   🔧 Set :started_by_flamelex? = #{Application.get_env(:quillex, :started_by_flamelex?)}")

    # Use the same application startup approach as mix test
    # Mix.shell().info("   🔧 Starting applications using mix test approach...")
    case Mix.Task.run("app.start") do
      :ok ->
        # Mix.shell().info("   ✅ All applications started successfully")
        File.cd!(original_dir)
        {:app_started, :quillex}
      error ->
        Mix.shell().error("❌ Failed to start applications: #{inspect(error)}")
        File.cd!(original_dir)
        System.halt(1)
    end
  end

  defp cleanup_existing_process(port) do
    case System.cmd("lsof", ["-i", ":#{port}"], stderr_to_stdout: true) do
      {output, 0} ->
        # Parse PID from lsof output
        case Regex.run(~r/\s+(\d+)\s+/, output) do
          [_, pid] ->
            Mix.shell().info("   🧹 Killing existing process #{pid} on port #{port}")
            System.cmd("kill", ["-9", pid])
            :timer.sleep(1000)
          _ ->
            :ok
        end
      _ ->
        :ok
    end
  end

  defp wait_for_mcp_server(config) do
    Mix.shell().info("⏳ Waiting for MCP server on port #{config.port}...")

    max_attempts = 30
    attempt = 0

    wait_loop(config.port, attempt, max_attempts)
  end

  defp wait_loop(port, attempt, max_attempts) when attempt < max_attempts do
    case :gen_tcp.connect('localhost', port, [:binary, {:active, false}]) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        Mix.shell().info("   ✅ MCP server ready on port #{port}")
        :ok
      {:error, _} ->
        :timer.sleep(1000)
        wait_loop(port, attempt + 1, max_attempts)
    end
  end

  defp wait_loop(port, _attempt, _max_attempts) do
    Mix.shell().error("❌ MCP server failed to start on port #{port}")
    System.halt(1)
  end

  defp setup_screenshot_dir(config) do
    File.mkdir_p!(config.screenshot_dir)
    Mix.shell().info("📸 Screenshot directory: #{config.screenshot_dir}")
  end

  defp configure_exunit(opts, config) do
    timeout = config.timeout

    exunit_config = [
      colors: [enabled: true],
      formatters: [ExUnit.CLIFormatter],
      timeout: timeout
    ]

    exunit_config = if opts[:only_spex] do
      Keyword.put(exunit_config, :include, [spex: true])
    else
      exunit_config
    end

    exunit_config = if config.verbose do
      Keyword.put(exunit_config, :trace, true)
    else
      exunit_config
    end

    # Set up global spex configuration
    Application.put_env(:spex, :adapter, Spex.Adapters.ScenicMCP)
    Application.put_env(:spex, :port, config.port)
    Application.put_env(:spex, :screenshot_dir, config.screenshot_dir)
    Application.put_env(:spex, :speed, config.speed)

    ExUnit.start(exunit_config)
  end

  defp load_spex_files(spex_files, config) do
    Mix.shell().info("📝 Loading #{length(spex_files)} spex file(s)...")

    Enum.each(spex_files, fn file ->
      try do
        Mix.shell().info("   📄 Loading #{Path.basename(file)}")
        Code.require_file(file)
      rescue
        error ->
          Mix.shell().error("Failed to load #{file}: #{Exception.message(error)}")
          System.halt(1)
      end
    end)
  end

  defp run_spex_tests(spex_files, config) do
    if config.sequential do
      Mix.shell().info("⚡ Running spex sequentially at #{config.speed} speed...")
    else
      Mix.shell().info("⚡ Running spex concurrently at #{config.speed} speed...")
    end

    apply_speed_settings(config.speed)

    # Run the tests
    ExUnit.run()
  end

  defp prompt_manual_start(config) do
    Mix.shell().info("""

    🎮 MANUAL MODE ACTIVATED
    ========================

    The application is now running and ready for interactive testing.
    You will be prompted before each action to:

    ⏸️  Press ENTER to proceed with the next step
    📸 Type 's' + ENTER to take a screenshot
    🔍 Type 'i' + ENTER to inspect viewport
    ❌ Type 'q' + ENTER to quit

    This allows you to observe each step in detail and see exactly
    what the AI is doing to your application.

    📍 Application: #{config.app_path}
    🌐 Port: #{config.port}
    📸 Screenshots: #{config.screenshot_dir}
    """)

    Mix.shell().prompt("Press ENTER when ready to start the spex tests...")
  end

  defp apply_speed_settings(speed) do
    delay_ms = case speed do
      :slow -> 2000
      :normal -> 500
      :fast -> 100
      :manual -> 0  # No automatic delay in manual mode
    end

    # Store delay for adapters to use
    Application.put_env(:spex, :step_delay, delay_ms)
    Application.put_env(:spex, :manual_mode, speed == :manual)
  end

  defp handle_results(results, config) do
    case results do
      %{failures: 0} ->
        Mix.shell().info("✅ All spex passed!")

        if config.watch do
          Mix.shell().info("👁️  Watch mode enabled - GUI will remain open")
          Mix.shell().info("   Press Ctrl+C to exit")

          # Keep alive for observation
          receive do
            :shutdown -> :ok
          end
        end

      %{failures: failures} when failures > 0 ->
        Mix.shell().error("❌ #{failures} spex failed")

        if config.watch do
          Mix.shell().info("👁️  Watch mode - GUI remains open for debugging")
          Mix.shell().info("   Press Ctrl+C to exit")

          receive do
            :shutdown -> :ok
          end
        end

        System.halt(1)

      _ ->
        Mix.shell().error("❌ Spex execution encountered errors")
        System.halt(1)
    end
  end

  defp cleanup_application({:app_started, app_name}, config) do
    Mix.shell().info("🧹 Cleaning up application...")
    :application.stop(app_name)

    Mix.shell().info("   ✅ Cleanup complete")
  end

  defp find_spex_files([], opts) do
    pattern = opts[:pattern] || @default_pattern
    Path.wildcard(pattern) |> Enum.sort()
  end

  defp find_spex_files(files, _opts) do
    files
    |> Enum.filter(&File.exists?/1)
    |> Enum.sort()
  end

  defp app_already_running?(app_name) do
    Application.started_applications()
    |> Enum.any?(fn {name, _, _} -> name == app_name end)
  end
end
