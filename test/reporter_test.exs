defmodule SexySpex.ReporterTest do
  use ExUnit.Case, async: false

  alias SexySpex.Reporter

  @jsonl_test_path "test_reporter_failures.jsonl"

  setup do
    # Clean up any test files
    File.rm(@jsonl_test_path)

    # Reset application env
    Application.delete_env(:sexy_spex, :jsonl_enabled)
    Application.delete_env(:sexy_spex, :jsonl_path)
    Application.delete_env(:sexy_spex, :quiet)

    on_exit(fn ->
      File.rm(@jsonl_test_path)
      Application.delete_env(:sexy_spex, :jsonl_enabled)
      Application.delete_env(:sexy_spex, :jsonl_path)
      Application.delete_env(:sexy_spex, :quiet)
    end)

    :ok
  end

  describe "state tracking" do
    test "tracks spex name when started" do
      Reporter.start_spex("My Spex")
      Reporter.spex_passed("My Spex")
    end

    test "tracks scenario and steps" do
      Reporter.start_spex("Test Spex")
      Reporter.start_scenario("Test Scenario")
      Reporter.step("Given", "some precondition")
      Reporter.step("When", "some action")
      Reporter.step("Then", "some outcome")
      Reporter.scenario_passed("Test Scenario")
      Reporter.spex_passed("Test Spex")
    end
  end

  describe "JSONL output" do
    test "writes JSONL when enabled and failure occurs" do
      Application.put_env(:sexy_spex, :jsonl_enabled, true)
      Application.put_env(:sexy_spex, :jsonl_path, @jsonl_test_path)
      Application.put_env(:sexy_spex, :quiet, true)

      # Create empty file (as mix task does)
      File.write!(@jsonl_test_path, "")

      Reporter.start_spex("Failing Spex")
      Reporter.start_scenario("Failing Scenario")
      Reporter.step("Given", "setup is done")
      Reporter.step("When", "action is taken")
      Reporter.step("Then", "assertion fails")

      error = %ExUnit.AssertionError{message: "Test failure", left: 1, right: 2}
      stacktrace = [{__MODULE__, :test_fn, 0, [file: ~c"test/my_spex.exs", line: 42]}]

      Reporter.scenario_failed("Failing Scenario", error, stacktrace)
      Reporter.spex_failed("Failing Spex", error, stacktrace)

      assert File.exists?(@jsonl_test_path)
      content = File.read!(@jsonl_test_path)
      lines = String.split(content, "\n", trim: true)

      # Should only have one line (no duplicate)
      assert length(lines) == 1

      failure = Jason.decode!(hd(lines))

      assert failure["type"] == "failure"
      assert failure["spex"] == "Failing Spex"
      assert failure["scenario"] == "Failing Scenario"
      assert length(failure["steps"]) == 3

      [given_step, when_step, then_step] = failure["steps"]
      assert given_step["type"] == "Given"
      assert given_step["description"] == "setup is done"
      assert given_step["status"] == "passed"

      assert when_step["type"] == "When"
      assert when_step["status"] == "passed"

      assert then_step["type"] == "Then"
      assert then_step["status"] == "failed"

      assert failure["error"]["message"] =~ "Test failure"
      assert failure["error"]["line"] == 42
    end

    test "does not write JSONL when disabled" do
      Application.put_env(:sexy_spex, :jsonl_enabled, false)
      Application.put_env(:sexy_spex, :quiet, true)

      Reporter.start_spex("Test Spex")
      Reporter.start_scenario("Test Scenario")
      Reporter.step("Given", "setup")

      error = %ExUnit.AssertionError{message: "failure"}
      Reporter.scenario_failed("Test Scenario", error)
      Reporter.spex_failed("Test Spex", error)

      refute File.exists?(@jsonl_test_path)
    end

    test "includes left/right values for assertion errors" do
      Application.put_env(:sexy_spex, :jsonl_enabled, true)
      Application.put_env(:sexy_spex, :jsonl_path, @jsonl_test_path)
      Application.put_env(:sexy_spex, :quiet, true)
      File.write!(@jsonl_test_path, "")

      Reporter.start_spex("Assertion Test")
      Reporter.start_scenario("Compare Values")
      Reporter.step("Then", "values match")

      error = %ExUnit.AssertionError{message: "not equal", left: %{a: 1}, right: %{b: 2}}
      stacktrace = []

      Reporter.scenario_failed("Compare Values", error, stacktrace)
      Reporter.spex_failed("Assertion Test", error, stacktrace)

      content = File.read!(@jsonl_test_path)
      failure = Jason.decode!(content)

      assert failure["error"]["left"] == "%{a: 1}"
      assert failure["error"]["right"] == "%{b: 2}"
    end

    test "handles errors without left/right values" do
      Application.put_env(:sexy_spex, :jsonl_enabled, true)
      Application.put_env(:sexy_spex, :jsonl_path, @jsonl_test_path)
      Application.put_env(:sexy_spex, :quiet, true)
      File.write!(@jsonl_test_path, "")

      Reporter.start_spex("Runtime Error Test")
      Reporter.start_scenario("Crash Scenario")
      Reporter.step("When", "code runs")

      error = %RuntimeError{message: "Something went wrong"}
      stacktrace = [{__MODULE__, :crash, 0, [file: ~c"test/crash.exs", line: 10]}]

      Reporter.scenario_failed("Crash Scenario", error, stacktrace)
      Reporter.spex_failed("Runtime Error Test", error, stacktrace)

      content = File.read!(@jsonl_test_path)
      failure = Jason.decode!(content)

      assert failure["error"]["message"] == "Something went wrong"
      refute Map.has_key?(failure["error"], "left")
      refute Map.has_key?(failure["error"], "right")
    end
  end

  describe "step marking" do
    test "marks last step as failed when failure occurs" do
      Application.put_env(:sexy_spex, :jsonl_enabled, true)
      Application.put_env(:sexy_spex, :jsonl_path, @jsonl_test_path)
      Application.put_env(:sexy_spex, :quiet, true)
      File.write!(@jsonl_test_path, "")

      Reporter.start_spex("Step Marking Test")
      Reporter.start_scenario("Multi-step Scenario")
      Reporter.step("Given", "first step")
      Reporter.step("Given", "second step")
      Reporter.step("When", "action step")
      # Failure happens here, so "action step" should be marked failed

      error = %RuntimeError{message: "boom"}
      Reporter.scenario_failed("Multi-step Scenario", error)
      Reporter.spex_failed("Step Marking Test", error)

      content = File.read!(@jsonl_test_path)
      failure = Jason.decode!(content)

      steps = failure["steps"]
      assert length(steps) == 3

      # First two steps should be passed
      assert Enum.at(steps, 0)["status"] == "passed"
      assert Enum.at(steps, 1)["status"] == "passed"

      # Last step should be failed
      assert Enum.at(steps, 2)["status"] == "failed"
    end
  end
end
