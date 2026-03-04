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
          {:ok, %{}}
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

  The block must return `{:ok, context_updates}`.
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
    func_name = :"__sexy_spex_given_#{name}__"

    quote do
      @sexy_spex_givens unquote(name)

      defp unquote(func_name)(var!(context)) do
        _ = var!(context)
        unquote(block)
      end
    end
  end

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
    end
  end
end
