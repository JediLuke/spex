defmodule SexySpex.GivensSpex do
  use SexySpex

  register_given :test_user, context do
    {:ok, Map.put(context, :user, %{name: "Test User", email: "test@example.com"})}
  end

  register_given :with_timestamp, context do
    {:ok, Map.put(context, :timestamp, DateTime.utc_now())}
  end

  register_given :admin_role, context do
    {:ok, Map.put(context, :role, :admin)}
  end

  spex "Atom-based givens work" do
    scenario "single given by atom" do
      given_ :test_user

      then_ "context has user", context do
        assert context.user.name == "Test User"
        assert context.user.email == "test@example.com"
        {:ok, context}
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
        {:ok, context}
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
        {:ok, context}
      end
    end
  end
end
