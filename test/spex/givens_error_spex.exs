defmodule SexySpex.GivensErrorSpex do
  use SexySpex

  register_given :sets_flag, context do
    {:ok, Map.put(context, :flag, :set)}
  end

  spex "Step return contract" do
    scenario "registered given replaces context with returned value" do
      given_ "set initial data", context do
        {:ok, Map.put(context, :initial, "data")}
      end

      given_ :sets_flag

      then_ "both initial and given data present", context do
        assert context.initial == "data"
        assert context.flag == :set
        {:ok, context}
      end
    end

    scenario "step returning bare :ok raises" do
      given_ "set initial data", context do
        {:ok, Map.put(context, :initial, "data")}
      end

      then_ "raises on :ok return", context do
        assert_raise ArgumentError, ~r/must return \{:ok, context\}/, fn ->
          SexySpex.Runtime.process_step_result(:ok, "demo step")
        end

        {:ok, context}
      end
    end

    scenario "step returning non-{:ok, _} raises" do
      then_ "raises on garbage return", context do
        assert_raise ArgumentError, ~r/must return \{:ok, context\}/, fn ->
          SexySpex.Runtime.process_step_result({:error, "boom"}, "demo step")
        end

        {:ok, context}
      end
    end
  end
end
