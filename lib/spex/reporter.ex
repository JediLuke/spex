defmodule Spex.Reporter do
  @moduledoc """
  Handles reporting and output formatting for spex execution.

  Provides a clean interface for tracking spex execution progress and
  generating human-readable output.
  """

  @doc """
  Starts reporting for a new specification.
  """
  def start_spex(name, opts \\ []) do
    IO.puts("")
    IO.puts("🎯 Running Spex: #{name}")
    IO.puts(String.duplicate("=", 50))
    
    if description = opts[:description] do
      IO.puts("   #{description}")
    end
    
    if tags = opts[:tags] do
      tag_str = tags |> Enum.map(&"##{&1}") |> Enum.join(" ")
      IO.puts("   Tags: #{tag_str}")
    end
    
    IO.puts("")
  end

  @doc """
  Reports successful completion of a specification.
  """
  def spex_passed(name) do
    IO.puts("")
    IO.puts("✅ Spex completed: #{name}")
  end

  @doc """
  Reports failure of a specification.
  """
  def spex_failed(name, error) do
    IO.puts("")
    IO.puts("❌ Spex failed: #{name}")
    IO.puts("   Error: #{Exception.message(error)}")
  end

  @doc """
  Starts reporting for a new scenario.
  """
  def start_scenario(name) do
    IO.puts("  📋 Scenario: #{name}")
  end

  @doc """
  Reports successful completion of a scenario.
  """
  def scenario_passed(name) do
    IO.puts("  ✅ Scenario passed: #{name}")
    IO.puts("")
  end

  @doc """
  Reports failure of a scenario.
  """
  def scenario_failed(name, error) do
    IO.puts("  ❌ Scenario failed: #{name}")
    IO.puts("     Error: #{Exception.message(error)}")
    IO.puts("")
  end

  @doc """
  Reports execution of a Given-When-Then step.
  """
  def step(type, description) do
    IO.puts("    #{type}: #{description}")
  end
end