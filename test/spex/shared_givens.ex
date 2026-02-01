defmodule SexySpex.TestSharedGivens do
  use SexySpex.Givens

  given :shared_user do
    {:ok, %{shared_user: %{name: "Shared User", source: :shared_module}}}
  end

  given :shared_config do
    {:ok, Map.put(context, :config, %{env: :test, debug: true})}
  end
end
