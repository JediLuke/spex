# Load the shared givens module first
Code.require_file("shared_givens.ex", __DIR__)

defmodule SexySpex.ImportGivensSpex do
  use SexySpex
  import_givens SexySpex.TestSharedGivens

  # Also define a local given
  given :local_data do
    {:ok, %{local: "from this module"}}
  end

  spex "Imported givens work" do
    scenario "can use imported given" do
      given_ :shared_user

      then_ "context has shared user", context do
        assert context.shared_user.name == "Shared User"
        assert context.shared_user.source == :shared_module
        :ok
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
        :ok
      end
    end
  end
end
