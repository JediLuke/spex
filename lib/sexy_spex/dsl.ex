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
          scenario "admin sees all users", context do
            given_ :logged_in_user   # Uses registered given
            given_ :admin_privileges

            when_ "viewing dashboard", context do
              # context.user and context.admin are available
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
          scenario "...", context do
            given_ :logged_in_user  # From SharedGivens
          end
        end
      end
  """

  @doc """
  Registers a reusable given statement that can be invoked by atom.

  The block should return `:ok` or `{:ok, context_updates}`.
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
    quote do
      @sexy_spex_givens {unquote(name), unquote(Macro.escape(block))}
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
  defmacro __before_compile__(_env) do
    quote do
      @doc false
      def __givens__ do
        @sexy_spex_givens
        |> Enum.reverse()
        |> Keyword.new(fn {name, block} -> {name, block} end)
      end

      @doc false
      def __imported_givens_modules__ do
        case @sexy_spex_imported_givens do
          nil -> []
          modules -> List.wrap(modules)
        end
      end
    end
  end

  @doc false
  def __execute_given__(module, name, context) do
    givens = module.__givens__()

    case Keyword.fetch(givens, name) do
      {:ok, block} ->
        execute_given_block(block, context)

      :error ->
        imported = module.__imported_givens_modules__()

        result =
          Enum.find_value(imported, fn mod ->
            # Ensure the module is loaded before checking function_exported?
            # This is needed because modules compiled during mix compile may not
            # be loaded into the VM when running via mix spex
            Code.ensure_loaded(mod)

            if function_exported?(mod, :__givens__, 0) do
              mod_givens = mod.__givens__()

              case Keyword.fetch(mod_givens, name) do
                {:ok, block} -> {:found, block}
                :error -> nil
              end
            end
          end)

        case result do
          {:found, block} ->
            execute_given_block(block, context)

          nil ->
            raise ArgumentError, """
            No given registered with name #{inspect(name)}.

            Make sure you have defined it with:

                given #{inspect(name)} do
                  # setup code
                  {:ok, %{key: value}}
                end

            Or imported it from another module with:

                import_givens MyModule
            """
        end
    end
  end

  defp execute_given_block(block, context) do
    {result, _binding} = Code.eval_quoted(block, [context: context], __ENV__)
    result
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

      # Using a registered given (atom)
      given_ :logged_in_user

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
  defmacro given_(name) when is_atom(name) do
    quote do
      SexySpex.Reporter.step("Given", unquote(name))

      var!(context) =
        SexySpex.StepExecutor.execute_step("Given", unquote(name), fn ->
          var!(context) = var!(context)
          result = SexySpex.DSL.__execute_given__(__MODULE__, unquote(name), var!(context))

          case result do
            :ok ->
              var!(context)

            {:ok, %{} = new_context} ->
              # Merge new context into existing context
              Map.merge(var!(context), new_context)

            other ->
              raise ArgumentError, """
              Given #{inspect(unquote(name))} must return :ok or {:ok, context}.
              Got: #{inspect(other)}
              """
          end
        end)
    end
  end

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
        # Require explicit return values: :ok or {:ok, context}
        case result do
          :ok ->
            var!(unquote(context_var))  # Keep context unchanged
          {:ok, %{} = new_context} ->
            new_context  # Use new context
          other ->
            raise ArgumentError, """
            Step must return :ok or {:ok, context}.
            Got: #{inspect(other)}

            Valid examples:
              :ok                                    # Keep context unchanged
              {:ok, context}                         # Return updated context
              {:ok, Map.put(context, :key, value)}   # Return modified context
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
        # Require explicit return values: :ok or {:ok, context}
        case result do
          :ok ->
            var!(unquote(context_var))  # Keep context unchanged
          {:ok, %{} = new_context} ->
            new_context  # Use new context
          other ->
            raise ArgumentError, """
            Step must return :ok or {:ok, context}.
            Got: #{inspect(other)}

            Valid examples:
              :ok                                    # Keep context unchanged
              {:ok, context}                         # Return updated context
              {:ok, Map.put(context, :key, value)}   # Return modified context
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
        # Require explicit return values: :ok or {:ok, context}
        case result do
          :ok ->
            var!(unquote(context_var))  # Keep context unchanged
          {:ok, %{} = new_context} ->
            new_context  # Use new context
          other ->
            raise ArgumentError, """
            Step must return :ok or {:ok, context}.
            Got: #{inspect(other)}

            Valid examples:
              :ok                                    # Keep context unchanged
              {:ok, context}                         # Return updated context
              {:ok, Map.put(context, :key, value)}   # Return modified context
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
        # Require explicit return values: :ok or {:ok, context}
        case result do
          :ok ->
            var!(unquote(context_var))  # Keep context unchanged
          {:ok, %{} = new_context} ->
            new_context  # Use new context
          other ->
            raise ArgumentError, """
            Step must return :ok or {:ok, context}.
            Got: #{inspect(other)}

            Valid examples:
              :ok                                    # Keep context unchanged
              {:ok, context}                         # Return updated context
              {:ok, Map.put(context, :key, value)}   # Return modified context
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
