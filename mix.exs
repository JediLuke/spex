defmodule Spex.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/your-org/spex"

  def project do
    [
      app: :spex,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Documentation
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      
      # Testing
      {:excoveralls, "~> 0.10", only: :test},
      
      # Code quality
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end

  defp description do
    """
    Executable specifications for AI-driven development.

    Spex provides a framework for writing executable specifications that serve as
    both tests and living documentation, optimized for AI-driven development workflows.
    Features include a clean DSL, adapter system for different testing environments,
    and built-in support for visual testing with Scenic applications.
    """
  end

  defp package do
    [
      name: "spex",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Documentation" => "https://hexdocs.pm/spex"
      },
      maintainers: ["Your Name"],
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "CHANGELOG.md": [title: "Changelog"]
      ],
      groups_for_modules: [
        "Core": [Spex, Spex.DSL, Spex.Reporter],
        "Adapters": [Spex.Adapters.Default, Spex.Adapters.ScenicMCP],
        "Mix Tasks": [Mix.Tasks.Spex]
      ]
    ]
  end
end