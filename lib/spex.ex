defmodule Spex do
  @moduledoc """
  Executable specifications for AI-driven development.

  Spex provides a framework for writing executable specifications that serve as
  both tests and living documentation, optimized for AI-driven development workflows.

  ## Basic Example

      defmodule MyApp.UserSpex do
        use Spex

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

  For GUI applications, use setup_all blocks to manage application lifecycle:

      defmodule MyApp.GUISpex do
        use Spex

        setup_all do
          # Start your application once for all spex
          Application.ensure_all_started(:my_gui_app)
          on_exit(fn -> Application.stop(:my_gui_app) end)
          {:ok, %{port: 9999}}
        end

        setup do
          # Reset state before each spex
          {:ok, %{timestamp: DateTime.utc_now()}}
        end

        spex "GUI interaction works", context do
          scenario "text input", context do
            given_ "empty editor", context do
              Spex.Adapters.ScenicMCP.take_screenshot("before_typing")
              context
            end

            when_ "user types text", context do
              Spex.Adapters.ScenicMCP.send_text("Hello World")
              context
            end

            then_ "text appears", context do
              Spex.Adapters.ScenicMCP.take_screenshot("after_typing")
              assert true
            end
          end
        end
      end

  """

  @doc false
  defmacro __using__(opts) do
    quote do
      use ExUnit.Case, async: false
      import Spex.DSL
      require Logger

      @spex_opts unquote(opts)
      @moduletag spex: true
    end
  end

end