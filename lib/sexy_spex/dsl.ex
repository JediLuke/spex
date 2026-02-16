defmodule SexySpex.DSL do
  @moduledoc """
  Domain-specific language for writing executable specifications.

  Provides macros for structuring specifications in a readable, executable format
  following the Given-When-Then pattern.

  ## Reusable Given Statements

  You can define reusable given statements at the module level using atoms:

      defmodule MyApp.UserSpex do
        use SexySpex

        # Define a reusable given
        given :logged_in_user do
          user = create_user()
          {:ok, %{user: user}}
        end

        # With context access
        given :admin_privileges do
          {:ok, Map.put(context, :admin, true)}
        end

        spex "User dashboard" do
          scenario "admin sees all users" do
            given_ :logged_in_user   # Uses registered given
            given_ :admin_privileges

            when_ "viewing dashboard", context do
              # context.user and context.admin are available
              {:ok, context}
            end
          end
        end
      end

  ## Sharing Givens Across Modules

  Create a shared givens module:

      defmodule MyApp.SharedGivens do
        use SexySpex.Givens

        given :logged_in_user do
          {:ok, %{user: create_user()}}
        end
      end

  Then import in your spex files:

      defmodule MyApp.SomeSpex do
        use SexySpex
        import_givens MyApp.SharedGivens

        spex "..." do
          scenario "..." do
            given_ :logged_in_user  # From SharedGivens
          end
        end
      end
  """

  @doc """
  Registers a reusable given statement that can be invoked by atom.

  The block must return `{:ok, context_updates}`.
  Context is available via the `context` variable.

  ## Examples

      given :valid_user do
        {:ok, %{user: %{name: "Test", email: "test@example.com"}}}
      end

      given :authenticated do
        token = authenticate(context.user)
        {:ok, Map.put(context, :token, token)}
      end
  """
  defmacro given(name, do: block) when is_atom(name) do
    func_name = :"__sexy_spex_given_#{name}__"

    quote do
      @sexy_spex_givens unquote(name)

      defp unquote(func_name)(var!(context)) do
        _ = var!(context)
        unquote(block)
      end
    end
  end

  @doc """
  Imports givens from another module.

  ## Example

      defmodule MyApp.SomeSpex do
        use SexySpex
        import_givens MyApp.SharedGivens
      end
  """
  defmacro import_givens(module) do
    quote do
      @sexy_spex_imported_givens unquote(module)
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    givens = Module.get_attribute(env.module, :sexy_spex_givens) |> Enum.reverse() |> Enum.uniq()

    call_clauses =
      for name <- givens do
        func_name = :"__sexy_spex_given_#{name}__"

        quote do
          def __call_given__(unquote(name), context) do
            unquote(func_name)(context)
          end
        end
      end

    quote do
      @doc false
      def __givens__, do: unquote(givens)

      unquote_splicing(call_clauses)

      @doc false
      def __imported_givens_modules__ do
        case @sexy_spex_imported_givens do
          nil -> []
          modules -> List.wrap(modules)
        end
      end
    end
  end

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
            SexySpex.Reporter.spex_failed(@spex_name, error, __STACKTRACE__)
            reraise error, __STACKTRACE__
        end
      end
    end
  end

  @doc """
  Defines a scenario within a specification.

  Scenarios group related Given-When-Then steps together.
  Context from ExUnit setup/setup_all is implicitly available as `context`.

  ## Example

      scenario "user workflow" do
        given_ "a user", context do
          user = create_user()
          {:ok, Map.put(context, :user, user)}
        end

        when_ "they login", context do
          session = login(context.user)
          {:ok, Map.put(context, :session, session)}
        end

        then_ "they see dashboard", context do
          assert context.session.valid?
          :ok
        end
      end
  """
  defmacro scenario(name, do: block) do
    quote do
      SexySpex.Reporter.start_scenario(unquote(name))

      try do
        # Use internal variable name to avoid shadowing user's `context`
        var!(spex_context) = case var!(exunit_context) do
          ctx when is_map(ctx) -> ctx
          ctx when is_list(ctx) -> Map.new(ctx)
          _ -> %{}
        end
        unquote(block)
        # Suppress "unused variable" warning for final step's assignment
        _ = var!(spex_context)
        SexySpex.Reporter.scenario_passed(unquote(name))
      rescue
        error ->
          SexySpex.Reporter.scenario_failed(unquote(name), error, __STACKTRACE__)
          reraise error, __STACKTRACE__
      end
    end
  end

  defmacro scenario(name, context_var, do: block) do
    quote do
      SexySpex.Reporter.start_scenario(unquote(name))

      try do
        var!(spex_context) = case var!(exunit_context) do
          ctx when is_map(ctx) -> ctx
          ctx when is_list(ctx) -> Map.new(ctx)
          _ -> %{}
        end
        # Bind the user's context variable to spex_context
        unquote(context_var) = var!(spex_context)
        unquote(block)
        _ = var!(spex_context)
        SexySpex.Reporter.scenario_passed(unquote(name))
      rescue
        error ->
          SexySpex.Reporter.scenario_failed(unquote(name), error, __STACKTRACE__)
          reraise error, __STACKTRACE__
      end
    end
  end

  @doc """
  Defines the preconditions for a test scenario.

  Steps receiving context must return `{:ok, context}` (bare `:ok` is not allowed).
  Steps without context just run their block and pass context through unchanged.

  ## Examples

      # Using a registered given (atom)
      given_ :logged_in_user

      # Without context - just run setup code (context passes through unchanged)
      given_ "some setup" do
        # setup code that doesn't need context
        :ok
      end

      # With context - must return {:ok, context}
      given_ "some setup", context do
        data = setup()
        {:ok, Map.put(context, :data, data)}
      end
  """
  defmacro given_(name) when is_atom(name) do
    quote do
      SexySpex.Reporter.step("Given", unquote(name))

      var!(spex_context) =
        SexySpex.StepExecutor.execute_step("Given", unquote(name), var!(spex_context), fn context ->
          result = SexySpex.Runtime.execute_given(__MODULE__, unquote(name), context)

          case result do
            {:ok, %{} = new_context} ->
              # Merge new context into existing context
              Map.merge(context, new_context)

            :ok ->
              raise ArgumentError, """
              Given #{inspect(unquote(name))} returned :ok, but atom-based givens must return {:ok, %{...}}.

              Change:

                  given #{inspect(unquote(name))} do
                    ...
                    :ok
                  end

              To:

                  given #{inspect(unquote(name))} do
                    ...
                    {:ok, %{}}
                  end
              """

            other ->
              raise ArgumentError, """
              Given #{inspect(unquote(name))} must return {:ok, %{...}}.
              Got: #{inspect(other)}
              """
          end
        end)
    end
  end

  defmacro given_(description, do: block) do
    quote do
      SexySpex.Reporter.step("Given", unquote(description))

      var!(spex_context) = SexySpex.StepExecutor.execute_step(
        "Given",
        unquote(description),
        var!(spex_context),
        fn spex_ctx ->
          unquote(block)
          spex_ctx
        end
      )
    end
  end

  defmacro given_(description, context_var, do: block) do
    quote do
      SexySpex.Reporter.step("Given", unquote(description))
      # Pass context as function argument (like ExUnit setup)
      var!(spex_context) = SexySpex.StepExecutor.execute_step(
        "Given",
        unquote(description),
        var!(spex_context),
        fn unquote(context_var) ->
          SexySpex.Runtime.process_context_step_result("Given", unquote(description), unquote(block))
        end
      )
    end
  end

  @doc """
  Defines the action being tested.
  """
  defmacro when_(description, do: block) do
    quote do
      SexySpex.Reporter.step("When", unquote(description))

      var!(spex_context) = SexySpex.StepExecutor.execute_step(
        "When",
        unquote(description),
        var!(spex_context),
        fn spex_ctx ->
          unquote(block)
          spex_ctx
        end
      )
    end
  end

  defmacro when_(description, context_var, do: block) do
    quote do
      SexySpex.Reporter.step("When", unquote(description))
      # Pass context as function argument (like ExUnit setup)
      var!(spex_context) = SexySpex.StepExecutor.execute_step(
        "When",
        unquote(description),
        var!(spex_context),
        fn unquote(context_var) ->
          SexySpex.Runtime.process_context_step_result("When", unquote(description), unquote(block))
        end
      )
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
      # Pass context as function argument (like ExUnit setup)
      var!(spex_context) = SexySpex.StepExecutor.execute_step(
        "Then",
        unquote(description),
        var!(spex_context),
        fn unquote(context_var) ->
          SexySpex.Runtime.process_step_result(unquote(block), unquote(context_var))
        end
      )
    end
  end

  @doc """
  Defines additional context or cleanup.
  """
  defmacro and_(description, do: block) do
    quote do
      SexySpex.Reporter.step("And", unquote(description))

      var!(spex_context) = SexySpex.StepExecutor.execute_step(
        "And",
        unquote(description),
        var!(spex_context),
        fn spex_ctx ->
          unquote(block)
          spex_ctx
        end
      )
    end
  end

  defmacro and_(description, context_var, do: block) do
    quote do
      SexySpex.Reporter.step("And", unquote(description))
      # Pass context as function argument (like ExUnit setup)
      var!(spex_context) = SexySpex.StepExecutor.execute_step(
        "And",
        unquote(description),
        var!(spex_context),
        fn unquote(context_var) ->
          SexySpex.Runtime.process_context_step_result("And", unquote(description), unquote(block))
        end
      )
    end
  end

  # Note: setup and setup_all are available directly from ExUnit.Case
  # Users can use them directly:
  #   setup do ... end
  #   setup_all do ... end
end
