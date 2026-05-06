# Load the shared givens module first
Code.require_file("shared_givens.ex", __DIR__)

defmodule SexySpex.ImportedGivensSpex do
  use SexySpex
  import SexySpex.TestSharedGivens

  # Also register a local given
  register_given :local_data, context do
    {:ok, Map.put(context, :local, "from this module")}
  end

  spex "Givens imported from another module work" do
    scenario "can use imported given" do
      given_ :shared_user

      then_ "context has shared user", context do
        assert context.shared_user.name == "Shared User"
        assert context.shared_user.source == :shared_module
        {:ok, context}
      end
    end

    scenario "can chain imported and local givens" do
      given_ :shared_user
      given_ :shared_config
      given_ :local_data

      then_ "all data is available", context do
        assert context.shared_user.source == :shared_module
        assert context.config.env == :test
        assert context.local == "from this module"
        {:ok, context}
      end
    end
  end
end
