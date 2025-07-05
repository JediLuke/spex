defmodule Spex do
  @moduledoc """
  Executable specifications for AI-driven development.

  Spex provides a framework for writing executable specifications that serve as
  both tests and living documentation, optimized for AI-driven development workflows.

  ## Example

      defmodule MyApp.UserSpex do
        use Spex

        spex "user registration works" do
          scenario "successful registration" do
            given "valid user data" do
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

  ## Configuration

  Spex can be configured with different adapters for various testing scenarios:

      config :spex,
        adapter: Spex.Adapters.ScenicMCP,
        screenshot_dir: "test/screenshots"

  """

  @doc false
  defmacro __using__(opts) do
    quote do
      use ExUnit.Case, async: false
      import Spex.DSL
      require Logger

      @spex_opts unquote(opts)
      @moduletag spex: true

      setup_all do
        Spex.setup(@spex_opts)
      end
    end
  end

  @doc """
  Sets up the spex environment with configuration.
  """
  def setup(opts \\ []) do
    adapter = opts[:adapter] || raise """
    No adapter specified! You must explicitly choose an adapter when using Spex.
    
    Example:
        use Spex, adapter: Spex.Adapters.ScenicMCP
    
    Available adapters:
    - Spex.Adapters.ScenicMCP - For Scenic GUI applications
    """
    
    # Get adapter defaults and merge with user options
    config = if function_exported?(adapter, :defaults, 0) do
      Map.merge(adapter.defaults(), Map.new(opts))
    else
      Map.new(opts)
    end
    
    # Set up global configuration for StepExecutor and other components
    Application.put_env(:spex, :adapter, adapter)
    Application.put_env(:spex, :config, config)
    
    # Initialize the adapter with merged configuration
    if function_exported?(adapter, :setup, 1) do
      adapter.setup(config)
    else
      if function_exported?(adapter, :setup, 0) do
        adapter.setup()
      end
    end
    
    :ok
  end
end