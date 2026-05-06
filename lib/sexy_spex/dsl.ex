defmodule SexySpex.DSL do
  @moduledoc """
  Domain-specific language for writing executable specifications.

  Provides macros for structuring specifications in a readable, executable format
  following the Given-When-Then pattern.

  ## Step return contract

  Every step block must return `{:ok, context}`. There is no implicit
  pass-through and no map-merge magic — the value you return becomes the
  context for the next step.

      given_ "user is logged in", context do
        user = create_user()
        {:ok, Map.put(context, :user, user)}
      end

      then_ "user can see dashboard", context do
        assert context.user.role == :member
        {:ok, context}
      end

  ## Reusable givens

  Register a reusable given inside a spex module:

      defmodule MyApp.UserSpex do
        use SexySpex

        register_given :logged_in_user, context do
          user = create_user()
          {:ok, Map.put(context, :user, user)}
        end

        spex "user dashboard" do
          scenario "logged-in user sees dashboard" do
            given_ :logged_in_user

            then_ "user is set", context do
              assert context.user
              {:ok, context}
            end
          end
        end
      end

  Share givens across modules with a normal Elixir `import`:

      defmodule MyApp.SharedGivens do
        use SexySpex.Givens

        register_given :logged_in_user, context do
          {:ok, Map.put(context, :user, create_user())}
        end
      end

      defmodule MyApp.ProfileSpex do
        use SexySpex
        import MyApp.SharedGivens

        spex "profile" do
          scenario "..." do
            given_ :logged_in_user
          end
        end
      end
  """

  @doc """
  Registers a reusable given by name.

  Generates a public function `def name(context)` whose body is the block.
  The block must return `{:ok, context}`.

  ## Examples

      register_given :valid_user, context do
        {:ok, Map.put(context, :user, %{name: "Test"})}
      end

      register_given :reset_database, context do
        MyApp.Repo.delete_all(MyApp.User)
        {:ok, context}
      end
  """
  defmacro register_given(name, context_var, do: block) when is_atom(name) do
    quote do
      def unquote(name)(unquote(context_var)) do
        unquote(block)
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
          {:ok, context}
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

  @doc """
  Defines preconditions for a scenario.

  Two forms:

      # Invoke a registered given by atom
      given_ :logged_in_user

      # Inline given — block must return {:ok, context}
      given_ "user signs up", context do
        user = sign_up()
        {:ok, Map.put(context, :user, user)}
      end
  """
  defmacro given_(name) when is_atom(name) do
    ctx_var = Macro.var(:ctx, __MODULE__)
    call_ast = {name, [], [ctx_var]}

    quote do
      SexySpex.Reporter.step("Given", unquote(name))

      var!(spex_context) =
        SexySpex.StepExecutor.execute_step(
          "Given",
          unquote(name),
          var!(spex_context),
          fn unquote(ctx_var) ->
            SexySpex.Runtime.process_step_result(unquote(call_ast), unquote(name))
          end
        )
    end
  end

  defmacro given_(description, context_var, do: block) do
    quote do
      SexySpex.Reporter.step("Given", unquote(description))

      var!(spex_context) =
        SexySpex.StepExecutor.execute_step(
          "Given",
          unquote(description),
          var!(spex_context),
          fn unquote(context_var) ->
            SexySpex.Runtime.process_step_result(unquote(block), unquote(description))
          end
        )
    end
  end

  @doc """
  Defines the action being tested. Block must return `{:ok, context}`.
  """
  defmacro when_(description, context_var, do: block) do
    quote do
      SexySpex.Reporter.step("When", unquote(description))

      var!(spex_context) =
        SexySpex.StepExecutor.execute_step(
          "When",
          unquote(description),
          var!(spex_context),
          fn unquote(context_var) ->
            SexySpex.Runtime.process_step_result(unquote(block), unquote(description))
          end
        )
    end
  end

  @doc """
  Defines the expected outcome. Block must return `{:ok, context}`.
  """
  defmacro then_(description, context_var, do: block) do
    quote do
      SexySpex.Reporter.step("Then", unquote(description))

      var!(spex_context) =
        SexySpex.StepExecutor.execute_step(
          "Then",
          unquote(description),
          var!(spex_context),
          fn unquote(context_var) ->
            SexySpex.Runtime.process_step_result(unquote(block), unquote(description))
          end
        )
    end
  end

  @doc """
  Defines additional context or cleanup. Block must return `{:ok, context}`.
  """
  defmacro and_(description, context_var, do: block) do
    quote do
      SexySpex.Reporter.step("And", unquote(description))

      var!(spex_context) =
        SexySpex.StepExecutor.execute_step(
          "And",
          unquote(description),
          var!(spex_context),
          fn unquote(context_var) ->
            SexySpex.Runtime.process_step_result(unquote(block), unquote(description))
          end
        )
    end
  end

  # Note: setup and setup_all are available directly from ExUnit.Case
  # Users can use them directly:
  #   setup do ... end
  #   setup_all do ... end
end
