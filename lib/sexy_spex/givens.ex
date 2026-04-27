defmodule SexySpex.Givens do
  @moduledoc """
  Defines a module of shared, reusable givens.

  `use SexySpex.Givens` makes `register_given/3` available so the module
  can register givens. Each registered given becomes a public function on
  the module, callable from any spex module that does a normal Elixir
  `import`.

  ## Example

      defmodule MyApp.SharedGivens do
        use SexySpex.Givens

        register_given :logged_in_user, context do
          {:ok, Map.put(context, :user, %{id: 1, name: "Test"})}
        end

        register_given :empty_database, context do
          MyApp.Repo.delete_all(MyApp.User)
          {:ok, context}
        end
      end

  Use them in spex files via plain `import`:

      defmodule MyApp.UserSpex do
        use SexySpex
        import MyApp.SharedGivens

        spex "user management" do
          scenario "admin views users" do
            given_ :logged_in_user
            given_ :empty_database

            when_ "viewing users list", context do
              {:ok, context}
            end
          end
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      import SexySpex.DSL, only: [register_given: 3]
    end
  end
end
