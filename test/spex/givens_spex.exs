defmodule SexySpex.GivensSpex do
  use SexySpex

  # Define reusable givens at module level
  given :test_user do
    {:ok, %{user: %{name: "Test User", email: "test@example.com"}}}
  end

  given :with_timestamp do
    {:ok, Map.put(context, :timestamp, DateTime.utc_now())}
  end

  given :admin_role do
    {:ok, Map.put(context, :role, :admin)}
  end

  spex "Atom-based givens work" do
    scenario "single given by atom" do
      given_ :test_user

      then_ "context has user", context do
        assert context.user.name == "Test User"
        assert context.user.email == "test@example.com"
        :ok
      end
    end

    scenario "chained givens by atom" do
      given_ :test_user
      given_ :with_timestamp
      given_ :admin_role

      then_ "context has all data", context do
        assert context.user.name == "Test User"
        assert context.timestamp != nil
        assert context.role == :admin
        :ok
      end
    end

    scenario "mixed atom and inline givens" do
      given_ :test_user

      given_ "additional setup", context do
        {:ok, Map.put(context, :extra, "inline data")}
      end

      then_ "both are available", context do
        assert context.user.name == "Test User"
        assert context.extra == "inline data"
        :ok
      end
    end
  end
end
