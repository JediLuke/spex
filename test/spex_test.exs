defmodule SpexTest do
  use ExUnit.Case
  doctest Spex

  test "Spex module exists and has documentation" do
    assert function_exported?(Spex, :setup, 1)
    
    # Test that the module has proper documentation
    {:docs_v1, _annotation, _language, _format, moduledoc, _metadata, _docs} = 
      Code.fetch_docs(Spex)
      
    assert moduledoc != :none
    assert moduledoc != :hidden
  end

  test "Default adapter is available" do
    assert Code.ensure_loaded?(Spex.Adapters.Default)
    assert function_exported?(Spex.Adapters.Default, :setup, 0)
    assert function_exported?(Spex.Adapters.Default, :take_screenshot, 1)
  end

  test "ScenicMCP adapter is available" do
    assert Code.ensure_loaded?(Spex.Adapters.ScenicMCP)
    assert function_exported?(Spex.Adapters.ScenicMCP, :setup, 0)
    assert function_exported?(Spex.Adapters.ScenicMCP, :take_screenshot, 1)
  end

  test "Mix task is available" do
    assert Code.ensure_loaded?(Mix.Tasks.Spex)
    assert function_exported?(Mix.Tasks.Spex, :run, 1)
  end
end

defmodule SpexIntegrationTest do
  use Spex

  test "can use spex DSL" do
    # This test validates that the spex DSL compiles and runs correctly
    assert true
  end

  spex "basic spex functionality works" do
    scenario "spex can execute simple assertions" do
      given "a basic test condition" do
        test_value = 42
        assert is_integer(test_value)
      end

      when_ "we perform a simple operation" do
        result = test_value * 2
        assert result == 84
      end

      then_ "the result is as expected" do
        assert result > test_value
      end
    end
  end

  spex "adapter integration works", tags: [:adapter] do
    scenario "default adapter functions correctly" do
      given "the default adapter is configured" do
        assert Application.get_env(:spex, :adapter) == Spex.Adapters.Default
      end

      when_ "we take a screenshot" do
        {:ok, result} = Spex.Adapters.Default.take_screenshot("test_screenshot")
        assert is_map(result)
        assert Map.has_key?(result, :filename)
      end

      then_ "the screenshot file is created" do
        assert File.exists?(result.filename)
        # Clean up
        File.rm!(result.filename)
      end
    end
  end
end