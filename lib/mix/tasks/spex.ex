defmodule Mix.Tasks.Spex do
  @shortdoc "Run executable specifications (spex)"
  @moduledoc """
  Run spex files - executable specifications for AI-driven development.

  Spex provides a framework for writing executable specifications that serve as
  both tests and living documentation, optimized for AI-driven development workflows.

  ## Usage

      mix spex                    # Run all spex files
      mix spex path/to/file.exs   # Run specific spex file
      mix spex --help             # Show this help

  ## Options

      --only-spex     Run only spex tests (skip regular ExUnit tests)
      --pattern       File pattern to match (default: test/spex/**/*_spex.exs)
      --verbose       Show detailed output
      --timeout       Test timeout in milliseconds (default: 60000)

  ## Examples

      mix spex
      mix spex test/spex/user_login_spex.exs
      mix spex --pattern "**/integration_*_spex.exs"
      mix spex --only-spex --verbose

  ## Configuration

  You can configure spex behavior in your config files:

      config :spex,
        adapter: Spex.Adapters.ScenicMCP,
        screenshot_dir: "test/screenshots",
        port: 9999

  """

  use Mix.Task

  @default_pattern "test/spex/**/*_spex.exs"
  @default_timeout 60_000

  def run(args) do
    {opts, files, _} = OptionParser.parse(args,
      switches: [
        only_spex: :boolean,
        pattern: :string,
        verbose: :boolean,
        timeout: :integer,
        help: :boolean
      ],
      aliases: [
        h: :help,
        v: :verbose
      ]
    )

    if opts[:help] do
      Mix.shell().info(@moduledoc)
      return()
    end

    Mix.Task.run("app.start")

    # Configure ExUnit for spex
    configure_exunit(opts)

    # Find and load spex files
    spex_files = find_spex_files(files, opts)

    if Enum.empty?(spex_files) do
      pattern = opts[:pattern] || @default_pattern
      Mix.shell().info("No spex files found matching pattern: #{pattern}")
      Mix.shell().info("Try: mix spex --help")
      return()
    end

    Mix.shell().info("🚀 Running #{length(spex_files)} spex file(s)...")

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
    case ExUnit.run() do
      %{failures: 0} ->
        Mix.shell().info("✅ All spex passed!")
        
      %{failures: failures} when failures > 0 ->
        Mix.shell().error("❌ #{failures} spex failed")
        System.halt(1)
        
      _ ->
        Mix.shell().error("❌ Spex execution encountered errors")
        System.halt(1)
    end
  end

  defp return, do: :ok

  defp configure_exunit(opts) do
    timeout = opts[:timeout] || @default_timeout
    
    config = [
      colors: [enabled: true],
      formatters: [ExUnit.CLIFormatter],
      timeout: timeout
    ]

    config = if opts[:only_spex] do
      Keyword.put(config, :include, [spex: true])
    else
      config
    end

    config = if opts[:verbose] do
      Keyword.put(config, :trace, true)
    else
      config
    end

    ExUnit.start(config)
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
end