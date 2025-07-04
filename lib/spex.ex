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
  Sets up the spex environment.
  """
  def setup(opts \\ []) do
    adapter = opts[:adapter] || Application.get_env(:spex, :adapter, Spex.Adapters.Default)
    
    if function_exported?(adapter, :setup, 0) do
      adapter.setup()
    end
    
    :ok
  end
end