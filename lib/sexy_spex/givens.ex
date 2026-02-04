defmodule SexySpex.Givens do
  @moduledoc """
  Module for defining shared, reusable given statements.

  Use this module to create a centralized repository of given statements
  that can be imported into multiple spex files.

  ## Example

      defmodule MyApp.SharedGivens do
        use SexySpex.Givens

        given :logged_in_user do
          {:ok, %{user: %{id: 1, name: "Test User"}}}
        end

        given :admin_user do
          {:ok, %{user: %{id: 1, name: "Admin", role: :admin}}}
        end

        given :empty_database do
          MyApp.Repo.delete_all(MyApp.User)
          :ok
        end
      end

  Then in your spex files:

      defmodule MyApp.UserSpex do
        use SexySpex
        import_givens MyApp.SharedGivens

        spex "User management" do
          scenario "admin can view users" do
            given_ :admin_user
            given_ :empty_database

            when_ "viewing users list", context do
              # ...
            end
          end
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      import SexySpex.Givens, only: [given: 2]

      Module.register_attribute(__MODULE__, :sexy_spex_givens, accumulate: true)

      @before_compile SexySpex.Givens
    end
  end

  @doc """
  Registers a reusable given statement.

  The block should return `:ok` or `{:ok, context_updates}`.
  Access the current context via `context` variable.

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

  defmacro __before_compile__(_env) do
    quote do
      @doc false
      def __givens__ do
        @sexy_spex_givens
        |> Enum.reverse()
        |> Keyword.new(fn {name, block} -> {name, block} end)
      end
    end
  end
end
