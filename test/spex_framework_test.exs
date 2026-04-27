defmodule SexySpex.FrameworkTest do
  @moduledoc """
  Comprehensive tests for SexySpex framework functionality.

  Tests the core features that matter:
  - DSL macros are available and work
  - Context passing between steps
  - Setup lifecycle (setup_all/setup)
  - Helper function availability
  """
  use SexySpex

  setup_all do
    # Test that setup_all provides shared context
    {:ok, %{app_name: "spex_test", shared_data: "available_to_all"}}
  end

  setup do
    # Test that setup runs before each spex
    {:ok, %{test_run_time: DateTime.utc_now()}}
  end

  spex "Core DSL functionality works" do
    scenario "spex/scenario/given/when/then macros are available" do
      given_ "we can use DSL macros", context do
        # Test basic assertion and context
        assert context.app_name == "spex_test"
        assert context.shared_data == "available_to_all"
        {:ok, Map.put(context, :initial_value, 10)}
      end

      when_ "we modify context data", context do
        # Test context flow between steps
        assert context.initial_value == 10
        result = context.initial_value * 2
        {:ok, Map.put(context, :computed_value, result)}
      end

      then_ "context data persists correctly", context do
        # Test final context state
        assert context.initial_value == 10
        assert context.computed_value == 20
        assert Map.has_key?(context, :test_run_time)
        {:ok, context}
      end
    end
  end

  spex "Framework modules are properly loaded" do
    scenario "essential modules are available" do
      given_ "the framework is loaded", context do
        assert Code.ensure_loaded?(SexySpex.DSL)
        assert Code.ensure_loaded?(SexySpex.Helpers)
        assert Code.ensure_loaded?(Mix.Tasks.Spex)
        {:ok, context}
      end

      when_ "we check DSL macros", context do
        macros = SexySpex.DSL.__info__(:macros)
        assert Keyword.has_key?(macros, :spex)
        assert Keyword.has_key?(macros, :scenario)
        assert Keyword.has_key?(macros, :given_)
        assert Keyword.has_key?(macros, :when_)
        assert Keyword.has_key?(macros, :then_)
        assert Keyword.has_key?(macros, :register_given)
        {:ok, context}
      end

      then_ "helper functions are available", context do
        helpers = SexySpex.Helpers.__info__(:functions)
        assert Keyword.has_key?(helpers, :start_scenic_app)
        assert Keyword.has_key?(helpers, :can_connect_to_scenic_mcp?)
        assert Keyword.has_key?(helpers, :application_running?)
        {:ok, context}
      end
    end
  end

  spex "Setup lifecycle works correctly" do
    scenario "setup_all and setup provide expected context" do
      given_ "setup_all has run once", context do
        # Verify setup_all data is available
        assert context.shared_data == "available_to_all"
        assert context.app_name == "spex_test"
        {:ok, context}
      end

      when_ "setup has run for this spex", context do
        # Verify setup data is available and recent
        assert Map.has_key?(context, :test_run_time)
        time_diff = DateTime.diff(DateTime.utc_now(), context.test_run_time)
        assert time_diff < 5  # Should be very recent
        {:ok, context}
      end

      then_ "both contexts are merged correctly", context do
        # Verify we have both setup_all and setup data
        assert context.shared_data == "available_to_all"  # from setup_all
        assert Map.has_key?(context, :test_run_time)      # from setup
        {:ok, context}
      end
    end
  end

  spex "Context isolation between steps" do
    scenario "each step receives context from previous step, not outer scope" do
      given_ "we set initial context", context do
        # Start with a known value
        {:ok, Map.put(context, :step1_value, 100)}
      end

      given_ "we modify context in second given", context do
        # Should see step1_value from previous step
        assert context.step1_value == 100
        # Add our own value
        {:ok, Map.merge(context, %{step2_value: 200, step1_value: 999})}
      end

      when_ "we check context in when block", context do
        # Should see modified step1_value (999) not original (100)
        assert context.step1_value == 999
        assert context.step2_value == 200
        {:ok, Map.put(context, :when_value, 300)}
      end

      then_ "context threads correctly through all steps", context do
        # Verify all values are present and correctly threaded
        assert context.step1_value == 999  # Modified by step2
        assert context.step2_value == 200
        assert context.when_value == 300
        {:ok, context}
      end
    end

    scenario "context parameter refers to inner binding not outer scope" do
      given_ "we establish baseline context", context do
        {:ok, Map.put(context, :baseline, "original")}
      end

      then_ "modifications in block use inner context", context do
        # This tests that `context` in the block refers to the step's
        # local binding, not the scenario's outer scope
        local_context = Map.put(context, :local_mod, true)
        assert local_context.baseline == "original"
        assert local_context.local_mod == true
        # Return unchanged — the local_mod should NOT leak
        {:ok, context}
      end

      then_ "previous step's local modifications don't leak", context do
        # local_mod from previous then_ should not be present
        refute Map.has_key?(context, :local_mod)
        assert context.baseline == "original"
        {:ok, context}
      end
    end
  end
end
