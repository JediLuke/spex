defmodule SexySpex.TestSharedGivens do
  use SexySpex.Givens

  register_given :shared_user, context do
    {:ok, Map.put(context, :shared_user, %{name: "Shared User", source: :shared_module})}
  end

  register_given :shared_config, context do
    {:ok, Map.put(context, :config, %{env: :test, debug: true})}
  end
end
