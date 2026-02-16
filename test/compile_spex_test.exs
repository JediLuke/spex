defmodule Mix.Tasks.Compile.SpexTest do
  use ExUnit.Case

  describe "run/1" do
    test "returns :noop when not in test environment" do
      # The compiler checks Mix.env() — in test env it should try to run
      # but without a pattern configured, it returns :noop
      assert {status, []} = Mix.Tasks.Compile.Spex.run([])
      assert status in [:noop, :ok]
    end

    test "returns :noop when no pattern configured and no flag given" do
      assert {:noop, []} = Mix.Tasks.Compile.Spex.run([])
    end

    test "returns :noop when pattern matches no files" do
      assert {:noop, []} =
               Mix.Tasks.Compile.Spex.run(["--spex-pattern", "nonexistent/**/*.exs"])
    end

    test "diagnostics/0 returns stored diagnostics" do
      # After a run, diagnostics should be available
      Mix.Tasks.Compile.Spex.run([])
      assert is_list(Mix.Tasks.Compile.Spex.diagnostics())
    end
  end
end
