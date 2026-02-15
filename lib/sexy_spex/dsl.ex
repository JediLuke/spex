defmodule SexySpex.DSL do
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
    * `:fail_on_error_logs` - Fail the test if any error logs are emitted (default: true)

  ## Error Log Detection

  By default, spex will fail if any error-level logs are emitted during test execution,
  even if no assertion failed. This catches crashes and errors that might go unnoticed.

  To disable for a specific spex:

      spex "my test", fail_on_error_logs: false do
        # This test won't fail on error logs
      end

  """
  defmacro spex(name, opts \\ [], do: block) do
    quote do
      @spex_name unquote(name)
      @spex_opts unquote(opts)

      test "Spex: #{unquote(name)}", context do
        SexySpex.Reporter.start_spex(@spex_name, @spex_opts)

        # Start error capture and clear any previous errors
        fail_on_errors = Keyword.get(@spex_opts, :fail_on_error_logs, true)
        if fail_on_errors do
          SexySpex.ErrorCapture.start()
          SexySpex.ErrorCapture.clear()
        end

        try do
          # Make ExUnit context available to scenarios
          var!(exunit_context) = context
          unquote(block)

          # Check for error logs if enabled
          if fail_on_errors and SexySpex.ErrorCapture.has_errors?() do
            error_msg = SexySpex.ErrorCapture.format_errors()
            SexySpex.ErrorCapture.clear()
            SexySpex.Reporter.spex_failed(@spex_name, %{message: error_msg})
            raise ExUnit.AssertionError, message: error_msg
          end

          SexySpex.Reporter.spex_passed(@spex_name)
        rescue
          error ->
            # Clear errors on failure to avoid double-reporting
            if fail_on_errors, do: SexySpex.ErrorCapture.clear()
            SexySpex.Reporter.spex_failed(@spex_name, error)
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
      SexySpex.Reporter.start_scenario(unquote(name))

      try do
        unquote(block)
        SexySpex.Reporter.scenario_passed(unquote(name))
      rescue
        error ->
          SexySpex.Reporter.scenario_failed(unquote(name), error)
          reraise error, __STACKTRACE__
      end
    end
  end
  
  @doc """
  Defines a scenario with context support.

  Context is passed between steps similar to ExUnit's approach.
  
  ## Example
  
      scenario "user workflow", context do
        given_ "a user", context do
          user = create_user()
          context = Map.put(context, :user, user)
        end
        
        when_ "they login", context do
          session = login(context.user)
          context = Map.put(context, :session, session)
        end
        
        then_ "they see dashboard", context do
          assert context.session.valid?
        end
      end
  """
  defmacro scenario(name, context_var, do: block) do
    quote do
      SexySpex.Reporter.start_scenario(unquote(name))

      try do
        # Use the ExUnit context that comes from setup/setup_all
        # Convert the context keyword list to a map for easier access
        var!(unquote(context_var)) = case var!(exunit_context) do
          context when is_map(context) -> context
          context when is_list(context) -> Map.new(context)
          _ -> %{}
        end
        unquote(block)
        SexySpex.Reporter.scenario_passed(unquote(name))
      rescue
        error ->
          SexySpex.Reporter.scenario_failed(unquote(name), error)
          reraise error, __STACKTRACE__
      end
    end
  end

  @doc """
  Defines the preconditions for a test scenario.
  
  ## Examples
  
      # Without context
      given_ "some setup" do
        # setup code
      end
      
      # With context (ExUnit style)
      given_ "some setup", context do
        data = setup()
        context = Map.put(context, :data, data)
      end
  """
  defmacro given_(description, do: block) do
    quote do
      SexySpex.Reporter.step("Given", unquote(description))
      
      SexySpex.StepExecutor.execute_step("Given", unquote(description), fn ->
        unquote(block)
      end)
    end
  end
  
  defmacro given_(description, context_var, do: block) do
    quote do
      SexySpex.Reporter.step("Given", unquote(description))
      var!(unquote(context_var)) = SexySpex.StepExecutor.execute_step("Given", unquote(description), fn ->
        var!(unquote(context_var)) = var!(unquote(context_var))
        result = unquote(block)
        # Handle return values: :ok, {:ok, context}, {:error, reason}, or a map
        case result do
          :ok ->
            var!(unquote(context_var))  # Keep context unchanged
          {:ok, %{} = new_context} ->
            new_context  # Use new context from ok tuple
          {:error, reason} ->
            raise ExUnit.AssertionError, message: "Step failed with error: #{inspect(reason)}"
          %{} = new_context ->
            new_context  # Use new context directly
          other ->
            raise ArgumentError, """
            Step must return :ok, {:ok, context}, {:error, reason}, or a context map.
            Got: #{inspect(other)}

            Valid examples:
              :ok                                    # Keep context unchanged
              {:ok, context}                         # Return updated context
              Map.put(context, :key, value)          # Return modified context directly
              {:error, reason}                       # Fail the step with an error
            """
        end
      end)
    end
  end

  @doc """
  Defines the action being tested.
  """
  defmacro when_(description, do: block) do
    quote do
      SexySpex.Reporter.step("When", unquote(description))
      
      SexySpex.StepExecutor.execute_step("When", unquote(description), fn ->
        unquote(block)
      end)
    end
  end
  
  defmacro when_(description, context_var, do: block) do
    quote do
      SexySpex.Reporter.step("When", unquote(description))
      
      var!(unquote(context_var)) = SexySpex.StepExecutor.execute_step("When", unquote(description), fn ->
        var!(unquote(context_var)) = var!(unquote(context_var))
        result = unquote(block)
        # Handle return values: :ok, {:ok, context}, {:error, reason}, or a map
        case result do
          :ok ->
            var!(unquote(context_var))  # Keep context unchanged
          {:ok, %{} = new_context} ->
            new_context  # Use new context from ok tuple
          {:error, reason} ->
            raise ExUnit.AssertionError, message: "Step failed with error: #{inspect(reason)}"
          %{} = new_context ->
            new_context  # Use new context directly
          other ->
            raise ArgumentError, """
            Step must return :ok, {:ok, context}, {:error, reason}, or a context map.
            Got: #{inspect(other)}

            Valid examples:
              :ok                                    # Keep context unchanged
              {:ok, context}                         # Return updated context
              Map.put(context, :key, value)          # Return modified context directly
              {:error, reason}                       # Fail the step with an error
            """
        end
      end)
    end
  end

  @doc """
  Defines the expected outcome.
  """
  defmacro then_(description, do: block) do
    quote do
      SexySpex.Reporter.step("Then", unquote(description))
      
      SexySpex.StepExecutor.execute_step("Then", unquote(description), fn ->
        unquote(block)
      end)
    end
  end
  
  defmacro then_(description, context_var, do: block) do
    quote do
      SexySpex.Reporter.step("Then", unquote(description))
      
      var!(unquote(context_var)) = SexySpex.StepExecutor.execute_step("Then", unquote(description), fn ->
        var!(unquote(context_var)) = var!(unquote(context_var))
        result = unquote(block)
        # Handle return values: :ok, {:ok, context}, {:error, reason}, or a map
        case result do
          :ok ->
            var!(unquote(context_var))  # Keep context unchanged
          {:ok, %{} = new_context} ->
            new_context  # Use new context from ok tuple
          {:error, reason} ->
            raise ExUnit.AssertionError, message: "Step failed with error: #{inspect(reason)}"
          %{} = new_context ->
            new_context  # Use new context directly
          other ->
            raise ArgumentError, """
            Step must return :ok, {:ok, context}, {:error, reason}, or a context map.
            Got: #{inspect(other)}

            Valid examples:
              :ok                                    # Keep context unchanged
              {:ok, context}                         # Return updated context
              Map.put(context, :key, value)          # Return modified context directly
              {:error, reason}                       # Fail the step with an error
            """
        end
      end)
    end
  end

  @doc """
  Defines additional context or cleanup.
  """
  defmacro and_(description, do: block) do
    quote do
      SexySpex.Reporter.step("And", unquote(description))
      
      SexySpex.StepExecutor.execute_step("And", unquote(description), fn ->
        unquote(block)
      end)
    end
  end
  
  defmacro and_(description, context_var, do: block) do
    quote do
      SexySpex.Reporter.step("And", unquote(description))
      
      var!(unquote(context_var)) = SexySpex.StepExecutor.execute_step("And", unquote(description), fn ->
        var!(unquote(context_var)) = var!(unquote(context_var))
        result = unquote(block)
        # Handle return values: :ok, {:ok, context}, {:error, reason}, or a map
        case result do
          :ok ->
            var!(unquote(context_var))  # Keep context unchanged
          {:ok, %{} = new_context} ->
            new_context  # Use new context from ok tuple
          {:error, reason} ->
            raise ExUnit.AssertionError, message: "Step failed with error: #{inspect(reason)}"
          %{} = new_context ->
            new_context  # Use new context directly
          other ->
            raise ArgumentError, """
            Step must return :ok, {:ok, context}, {:error, reason}, or a context map.
            Got: #{inspect(other)}

            Valid examples:
              :ok                                    # Keep context unchanged
              {:ok, context}                         # Return updated context
              Map.put(context, :key, value)          # Return modified context directly
              {:error, reason}                       # Fail the step with an error
            """
        end
      end)
    end
  end

  # Note: setup and setup_all are available directly from ExUnit.Case
  # Users can use them directly:
  #   setup do ... end
  #   setup_all do ... end
end