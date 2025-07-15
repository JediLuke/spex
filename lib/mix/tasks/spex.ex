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

  ## Examples

      mix spex
      mix spex test/spex/user_login_spex.exs
      mix spex --pattern "**/integration_*_spex.exs"
      mix spex --only-spex --verbose
      mix spex --manual           # Interactive step-by-step mode

  ## Configuration

  You can configure spex behavior in your config files:

      config :sexy_spex,
        manual_mode: false,
        step_delay: 0

  Application lifecycle is handled in individual spex files using setup_all blocks.

  """

  use Mix.Task

  @default_pattern "test/spex/**/*_spex.exs"
  @default_timeout 60_000

  def run(args) do
    # Ensure we're running in test environment for spex
    Mix.env(:test)
    
    {opts, files, _} = OptionParser.parse(args,
      switches: [
        only_spex: :boolean,
        pattern: :string,
        verbose: :boolean,
        timeout: :integer,
        help: :boolean,
        manual: :boolean
      ],
      aliases: [
        h: :help,
        v: :verbose,
        m: :manual
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
    end
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
