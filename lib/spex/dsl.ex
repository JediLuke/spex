defmodule Spex.DSL do
  @moduledoc """
  Domain-specific language for writing executable specifications.

  Provides macros for structuring specifications in a readable, executable format
  following the Given-When-Then pattern.
  """

  @doc """
  Defines a specification.

  ## Example

      spex "user can login", tags: [:authentication] do
        scenario "with valid credentials" do
          # test implementation
        end
      end

  ## Options

    * `:description` - Human-readable description of the specification
    * `:tags` - List of atoms for categorizing the specification
    * `:context` - Map of additional context information

  """
  defmacro spex(name, opts \\ [], do: block) do
    quote do
      @spex_name unquote(name)
      @spex_opts unquote(opts)

      test "Spex: #{unquote(name)}" do
        Spex.Reporter.start_spex(@spex_name, @spex_opts)

        try do
          unquote(block)
          Spex.Reporter.spex_passed(@spex_name)
        rescue
          error ->
            Spex.Reporter.spex_failed(@spex_name, error)
            reraise error, __STACKTRACE__
        end
      end
    end
  end

  @doc """
  Defines a scenario within a specification.

  Scenarios group related Given-When-Then steps together.
  """
  defmacro scenario(name, do: block) do
    quote do
      Spex.Reporter.start_scenario(unquote(name))

      try do
        unquote(block)
        Spex.Reporter.scenario_passed(unquote(name))
      rescue
        error ->
          Spex.Reporter.scenario_failed(unquote(name), error)
          reraise error, __STACKTRACE__
      end
    end
  end

  @doc """
  Defines the preconditions for a test scenario.
  """
  defmacro given_(description, do: block) do
    quote do
      Spex.Reporter.step("Given", unquote(description))
      
      Spex.StepExecutor.execute_step("Given", unquote(description), fn ->
        unquote(block)
      end)
    end
  end

  @doc """
  Defines the action being tested.
  """
  defmacro when_(description, do: block) do
    quote do
      Spex.Reporter.step("When", unquote(description))
      
      Spex.StepExecutor.execute_step("When", unquote(description), fn ->
        unquote(block)
      end)
    end
  end

  @doc """
  Defines the expected outcome.
  """
  defmacro then_(description, do: block) do
    quote do
      Spex.Reporter.step("Then", unquote(description))
      
      Spex.StepExecutor.execute_step("Then", unquote(description), fn ->
        unquote(block)
      end)
    end
  end

  @doc """
  Defines additional context or cleanup.
  """
  defmacro and_(description, do: block) do
    quote do
      Spex.Reporter.step("And", unquote(description))
      
      Spex.StepExecutor.execute_step("And", unquote(description), fn ->
        unquote(block)
      end)
    end
  end
end