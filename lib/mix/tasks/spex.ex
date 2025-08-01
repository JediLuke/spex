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
      --verbose       Show detailed output
      --timeout       Test timeout in milliseconds (default: 60000)
      --manual        Interactive manual mode - step through each action
      --speed         Execution speed: fast (default), medium, slow
      --trace         Enable ExUnit trace mode (shows test execution details)

  ## Examples

      mix spex
      mix spex test/spex/user_login_spex.exs
      mix spex --pattern "**/integration_*_spex.exs"
      mix spex --only-spex --verbose
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
    
    {opts, files, _} = OptionParser.parse(args,
      switches: [
        only_spex: :boolean,
        pattern: :string,
        verbose: :boolean,
        timeout: :integer,
        help: :boolean,
        manual: :boolean,
        speed: :string,
        trace: :boolean
      ],
      aliases: [
        h: :help,
        v: :verbose,
        m: :manual,
        s: :speed,
        t: :trace
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

    Mix.shell().info("🎯 Running #{length(spex_files)} spex file(s)...")

    # Run spex tests with ExUnit
    run_tests_with_exunit(spex_files, opts)
  end

  defp return, do: :ok

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
    # Set manual mode if requested
    if opts[:manual] do
      Application.put_env(:sexy_spex, :manual_mode, true)
      Application.put_env(:sexy_spex, :step_delay, 0)
      Mix.shell().info("🎮 Manual mode enabled - you'll be prompted at each step")
    else
      # Configure speed if provided
      configure_speed(opts[:speed])
    end
  end

  defp configure_speed(nil), do: configure_speed("fast")  # Default to fast
  defp configure_speed("fast") do
    Application.put_env(:sexy_spex, :step_delay, 0)
  end
  defp configure_speed("medium") do
    Application.put_env(:sexy_spex, :step_delay, 1000)  # 1 second
    Mix.shell().info("⏱️  Medium speed mode - 1s delays between steps")
  end
  defp configure_speed("slow") do
    Application.put_env(:sexy_spex, :step_delay, 2500)  # 2.5 seconds
    Mix.shell().info("🐌 Slow speed mode - 2.5s delays between steps")
  end
  defp configure_speed(invalid) do
    Mix.shell().error("Invalid speed: #{invalid}. Valid options: fast, medium, slow")
    System.halt(1)
  end

  defp run_tests_with_exunit(spex_files, opts) do
    # Configure ExUnit
    timeout = opts[:timeout] || @default_timeout

    exunit_config = [
      colors: [enabled: true],
      formatters: [ExUnit.CLIFormatter],
      timeout: timeout
    ]

    # Note: Spex files can only be run via 'mix spex' command
    # This ensures proper compilation and application lifecycle management

    # Enable verbose output if requested
    exunit_config = if opts[:verbose] do
      Keyword.put(exunit_config, :trace, true)
    else
      exunit_config
    end

    # Enable trace mode if requested (can be used independently of verbose)
    exunit_config = if opts[:trace] do
      Keyword.put(exunit_config, :trace, true)
    else
      exunit_config
    end

    # Start ExUnit
    ExUnit.start(exunit_config)

    # Load spex files
    Enum.each(spex_files, fn file ->
      try do
        Code.require_file(file)
      rescue
        error ->
          Mix.shell().error("Failed to load #{file}: #{Exception.message(error)}")
          System.halt(1)
      end
    end)

    # Run the tests
    result = ExUnit.run()

    # Handle results and exit immediately to prevent double runs
    case result do
      %{failures: 0} ->
        Mix.shell().info("✅ All spex passed!")
        System.halt(0)  # Exit immediately after success

      %{failures: failures} when failures > 0 ->
        Mix.shell().error("❌ #{failures} spex failed")
        System.halt(1)

      _ ->
        Mix.shell().error("❌ Spex execution encountered errors")
        System.halt(1)
    end
  end
end
