defmodule SexySpex do
  @moduledoc """
  Executable specifications for AI-driven development.

  SexySpex provides a framework for writing executable specifications that serve as
  both tests and living documentation, optimized for AI-driven development workflows.

  ## Technical Architecture

  SexySpex is built on top of ExUnit but provides a controlled execution environment
  specifically designed for AI-driven testing. Here's how it works:

  ### Core Architecture

  1. **ExUnit Foundation**: SexySpex uses ExUnit.Case under the hood for all test execution
  2. **Custom DSL**: Adds spex/scenario/given_/when_/then_ macros via SexySpex.DSL
  3. **Controlled Execution**: Only runs via `mix spex` command, never through `mix test`
  4. **Framework Helpers**: Provides SexySpex.Helpers for common patterns like app startup

  ### Execution Flow

  ```
  mix spex → Mix.Tasks.Spex → ExUnit.start() → Load spex files → ExUnit.run()
  ```

  ### Why Not Standard ExUnit?

  - **Compilation Control**: `mix spex` ensures proper compilation for complex dependency trees
  - **Application Lifecycle**: Better control over starting/stopping GUI applications
  - **AI-Optimized**: Manual mode, step-by-step execution, semantic helpers
  - **Cleaner Interface**: No confusion about tags, includes, or execution methods

  ### File Structure

  ```
  test/spex/
    hello_world_spex.exs     # Basic connectivity test
    user_workflow_spex.exs   # Complex user interactions
    screenshots/             # Generated screenshots
  ```

  ### Under the Hood

  When you write:
  ```elixir
  use SexySpex
  ```

  You get:
  ```elixir
  use ExUnit.Case, async: false  # Standard ExUnit test case
  import SexySpex.DSL               # spex/scenario/given_/when_/then_
  require Logger                # Logging support
  ```

  This means you have access to all standard ExUnit features:
  - `assert`, `refute`, `assert_raise`, etc.
  - `setup_all`, `setup` callbacks
  - `on_exit` for cleanup
  - Pattern matching in tests

  ### SexySpex vs ExUnit

  | Feature | SexySpex | ExUnit |
  |---------|------|--------|
  | Execution | `mix spex` only | `mix test` |
  | File Pattern | `*_spex.exs` | `*_test.exs` |
  | DSL | Given/When/Then | test/describe |
  | Target Use | AI-driven GUI testing | General testing |
  | Manual Mode | ✅ Built-in | ❌ Not available |
  | App Lifecycle | ✅ Helpers provided | Manual setup |
  | Error Log Detection | ✅ Automatic | ❌ Manual |

  ### Integration with Scenic Applications

  SexySpex provides special helpers for Scenic GUI applications:
  - `SexySpex.Helpers.start_scenic_app/2` - Start app with MCP server
  - `SexySpex.Helpers.can_connect_to_scenic_mcp?/1` - Test connectivity
  - `SexySpex.Helpers.application_running?/1` - Check app status

  This makes AI-driven GUI testing much simpler and more reliable.

  ## Basic Example

      defmodule MyApp.UserSpex do
        use SexySpex

        spex "user registration works" do
          scenario "successful registration" do
            given_ "valid user data" do
              user_data = %{email: "test@example.com", password: "secure123"}
              assert valid_user_data?(user_data)
            end

            when_ "user registers" do
              {:ok, user} = MyApp.register_user(user_data)
              assert user.email == "test@example.com"
            end

            then_ "user can login" do
              assert {:ok, _session} = MyApp.authenticate(user_data.email, user_data.password)
            end
          end
        end
      end

  ## GUI Application Testing

  For GUI applications, use SexySpex.Helpers for easy setup:

      defmodule MyApp.GUISpex do
        use SexySpex

        setup_all do
          # Start GUI application with MCP server
          SexySpex.Helpers.start_scenic_app(:my_gui_app)
        end

        setup do
          # Reset state before each spex
          {:ok, %{timestamp: DateTime.utc_now()}}
        end

        spex "GUI interaction works", context do
          scenario "application connectivity", context do
            given_ "application is running", context do
              assert SexySpex.Helpers.application_running?(:my_gui_app)
              context
            end

            then_ "we can connect to MCP server", context do
              assert SexySpex.Helpers.can_connect_to_scenic_mcp?(context.port)
              context
            end
          end
        end
      end

  ## Running Spex

  SexySpex files can only be executed via the `mix spex` command:

      # Run all spex files
      mix spex

      # Run specific spex file
      mix spex test/spex/my_app_spex.exs

      # Run in manual mode (step-by-step)
      mix spex --manual

  **Important**: SexySpex files cannot be run via `mix test`. This ensures proper
  compilation and application lifecycle management for AI-driven testing.

  ## Error Log Detection

  SexySpex automatically captures error logs during test execution and fails the test
  if any errors are logged, even if no assertion failed. This catches:

  - GenServer crashes and terminations
  - FunctionClauseErrors and other runtime errors
  - Any `:error`, `:critical`, `:alert`, or `:emergency` level logs

  This is enabled by default. When errors are detected, you'll see output like:

      ❌ 2 error(s) logged during test execution:
        • [error] GenServer #PID<0.1234.0> terminating
        • [error] ** (FunctionClauseError) no function clause matching...

  ### Disabling Error Detection

  To disable error detection for a specific spex (e.g., when testing error handling):

      spex "error handling works", fail_on_error_logs: false do
        scenario "handles invalid input" do
          # This test expects errors to be logged
        end
      end

  ### Manual Error Capture

  You can also use the error capture module directly:

      # Start capturing
      SexySpex.ErrorCapture.start()
      SexySpex.ErrorCapture.clear()

      # ... do something ...

      # Check for errors
      if SexySpex.ErrorCapture.has_errors?() do
        IO.puts(SexySpex.ErrorCapture.format_errors())
      end

      # Get raw error list
      errors = SexySpex.ErrorCapture.get_errors()

  """

  @doc false
  defmacro __using__(opts) do
    quote do
      use ExUnit.Case, async: false
      import SexySpex.DSL
      require Logger

      # Register module attributes for givens
      Module.register_attribute(__MODULE__, :sexy_spex_givens, accumulate: true)
      Module.register_attribute(__MODULE__, :sexy_spex_imported_givens, accumulate: false)

      @before_compile SexySpex.DSL

      @spex_opts unquote(opts)
    end
  end

  defmodule Helpers do
    @moduledoc """
    Common helper functions for spex files.

    These helpers provide reusable patterns for application startup,
    connectivity testing, and other common spex operations.
    """

    @doc """
    Starts a Scenic application with MCP server and waits for it to be ready.

    This helper handles the common pattern of:
    1. Ensuring compilation (needed for mix spex)
    2. Starting the application
    3. Waiting for MCP server
    4. Setting up cleanup

    ## Parameters
    - `app_name` - The application atom (e.g., `:quillex`)
    - `opts` - Optional configuration
      - `:port` - MCP server port (default: 9999)
      - `:timeout_retries` - Connection timeout retries (default: 20)

    ## Returns
    - `{:ok, context}` with app_name and port on success
    - Raises on failure

    ## Example
        setup_all do
          start_scenic_app(:quillex)
        end
    """
    def start_scenic_app(app_name, opts \\ []) do
      port = Keyword.get(opts, :port, 9999)
      timeout_retries = Keyword.get(opts, :timeout_retries, 20)

      # Ensure compilation (needed when running through mix spex)
      Mix.Task.run("compile")

      # Ensure all applications are started
      case Application.ensure_all_started(app_name) do
        {:ok, _apps} ->
          IO.puts("🚀 #{String.capitalize(to_string(app_name))} started successfully")

          # Wait for MCP server to be ready
          wait_for_mcp_server(port, timeout_retries)

          # Cleanup when tests are done
          ExUnit.Callbacks.on_exit(fn ->
            IO.puts("🛑 Stopping #{String.capitalize(to_string(app_name))}")
            Application.stop(app_name)
          end)

          {:ok, %{app_name: to_string(app_name), port: port}}

        {:error, reason} ->
          IO.puts("❌ Failed to start #{String.capitalize(to_string(app_name))}: #{inspect(reason)}")
          raise "Failed to start #{String.capitalize(to_string(app_name))}: #{inspect(reason)}"
      end
    end

    @doc """
    Checks if we can connect to a Scenic MCP server on the given port.
    """
    def can_connect_to_scenic_mcp?(port) do
      case :gen_tcp.connect(~c"localhost", port, [:binary, {:active, false}]) do
        {:ok, socket} ->
          :gen_tcp.close(socket)
          true
        {:error, _reason} ->
          false
      end
    end

    @doc """
    Waits for MCP server to be ready with configurable retries.
    """
    def wait_for_mcp_server(port, retries \\ 20) do
      case can_connect_to_scenic_mcp?(port) do
        true ->
          IO.puts("✅ MCP server is ready on port #{port}")
          :ok
        false when retries > 0 ->
          Process.sleep(500)
          wait_for_mcp_server(port, retries - 1)
        false ->
          IO.puts("❌ MCP server failed to start on port #{port} after #{20 - retries} attempts")
          {:error, :mcp_server_timeout}
      end
    end

    @doc """
    Checks if an application is currently running.
    """
    def application_running?(app_name) do
      Application.started_applications()
      |> Enum.any?(fn {running_app, _, _} -> running_app == app_name end)
    end
  end

end
