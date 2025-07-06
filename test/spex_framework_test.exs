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
    scenario "spex/scenario/given/when/then macros are available", context do
      given_ "we can use DSL macros", context do
        # Test basic assertion and context
        assert context.app_name == "spex_test"
        assert context.shared_data == "available_to_all"
        Map.put(context, :initial_value, 10)
      end

      when_ "we modify context data", context do
        # Test context flow between steps
        assert context.initial_value == 10
        result = context.initial_value * 2
        Map.put(context, :computed_value, result)
      end

      then_ "context data persists correctly", context do
        # Test final context state
        assert context.initial_value == 10
        assert context.computed_value == 20
        assert Map.has_key?(context, :test_run_time)
      end
    end
  end

  spex "Framework modules are properly loaded" do
    scenario "essential modules are available" do
      given_ "the framework is loaded" do
        # Test that core modules exist
        assert Code.ensure_loaded?(SexySpex.DSL)
        assert Code.ensure_loaded?(SexySpex.Helpers)
        assert Code.ensure_loaded?(Mix.Tasks.Spex)
      end

      when_ "we check DSL macros" do
        # Test that DSL macros are defined
        macros = SexySpex.DSL.__info__(:macros)
        assert Keyword.has_key?(macros, :spex)
        assert Keyword.has_key?(macros, :scenario)
        assert Keyword.has_key?(macros, :given_)
        assert Keyword.has_key?(macros, :when_)
        assert Keyword.has_key?(macros, :then_)
      end

      then_ "helper functions are available" do
        # Test that helper functions exist
        helpers = SexySpex.Helpers.__info__(:functions)
        assert Keyword.has_key?(helpers, :start_scenic_app)
        assert Keyword.has_key?(helpers, :can_connect_to_scenic_mcp?)
        assert Keyword.has_key?(helpers, :application_running?)
      end
    end
  end

  spex "Setup lifecycle works correctly" do
    scenario "setup_all and setup provide expected context", context do
      given_ "setup_all has run once", context do
        # Verify setup_all data is available
        assert context.shared_data == "available_to_all"
        assert context.app_name == "spex_test"
      end

      when_ "setup has run for this spex", context do
        # Verify setup data is available and recent
        assert Map.has_key?(context, :test_run_time)
        time_diff = DateTime.diff(DateTime.utc_now(), context.test_run_time)
        assert time_diff < 5  # Should be very recent
      end

      then_ "both contexts are merged correctly", context do
        # Verify we have both setup_all and setup data
        assert context.shared_data == "available_to_all"  # from setup_all
        assert Map.has_key?(context, :test_run_time)      # from setup
      end
    end
  end
end