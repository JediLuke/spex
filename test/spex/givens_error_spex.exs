defmodule SexySpex.GivensErrorSpex do
  use SexySpex

  given :returns_ok do
    :ok
  end

  given :returns_ok_with_data do
    {:ok, %{from_given: true}}
  end

  spex "Given return values work correctly" do
    scenario "given returning :ok keeps context unchanged", context do
      given_ "set initial data", context do
        {:ok, Map.put(context, :initial, "data")}
      end

      given_ :returns_ok

      then_ "initial data still present", context do
        assert context.initial == "data"
        :ok
      end
    end

    scenario "given returning {:ok, map} merges into context", context do
      given_ "set initial data", context do
        {:ok, Map.put(context, :initial, "data")}
      end

      given_ :returns_ok_with_data

      then_ "both initial and given data present", context do
        assert context.initial == "data"
        assert context.from_given == true
        :ok
      end
    end
  end
end
