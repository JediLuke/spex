defmodule SexySpex.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/JediLuke/spex"

  def project do
    [
      app: :sexy_spex,
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
    Executable specifications for AI-driven development. Built on ExUnit with Given-When-Then DSL, 
    manual mode, semantic helpers, and GUI testing support for Scenic applications.
    """
  end

  defp package do
    [
      name: "sexy_spex",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Documentation" => "https://hexdocs.pm/sexy_spex"
      },
      maintainers: ["Luke"],
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
        "Core": [SexySpex, SexySpex.DSL, SexySpex.Helpers, SexySpex.Reporter, SexySpex.StepExecutor],
        "Mix Tasks": [Mix.Tasks.Spex]
      ]
    ]
  end
end