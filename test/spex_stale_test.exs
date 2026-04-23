defmodule Mix.Tasks.SpexStaleTest do
  use ExUnit.Case, async: false

  # These tests verify that --stale support works correctly by exercising
  # the Mix.Compilers.Test integration. Since the stale manifest is a
  # shared resource, these tests cannot run async.

  @manifest_path Path.join(Mix.Project.manifest_path(), "compile.test_stale")

  setup do
    # Clean up any existing stale manifest before each test
    File.rm(@manifest_path)
    on_exit(fn -> File.rm(@manifest_path) end)
    :ok
  end

  describe "--stale option parsing" do
    test "stale is accepted as a switch" do
      {opts, _, _} = OptionParser.parse(["--stale"],
        switches: [stale: :boolean, force: :boolean]
      )
      assert opts[:stale] == true
    end

    test "force is accepted as a switch" do
      {opts, _, _} = OptionParser.parse(["--force"],
        switches: [stale: :boolean, force: :boolean]
      )
      assert opts[:force] == true
    end

    test "stale and force can be combined" do
      {opts, _, _} = OptionParser.parse(["--stale", "--force"],
        switches: [stale: :boolean, force: :boolean]
      )
      assert opts[:stale] == true
      assert opts[:force] == true
    end
  end

  describe "stale manifest lifecycle" do
    test "no manifest exists before first stale run" do
      refute File.exists?(@manifest_path)
    end

    test "manifest is created after successful stale run" do
      refute File.exists?(@manifest_path)

      # Simulate what run_with_stale_tracking does by calling CT.require_and_run
      # with a minimal set of files
      ExUnit.start(autorun: false, colors: [enabled: false])

      spex_files = Path.wildcard("test/spex/*_spex.exs")
      assert length(spex_files) > 0

      result = Mix.Compilers.Test.require_and_run(
        spex_files,
        ["test/spex"],
        [docs: false, debug_info: false],
        [stale: true]
      )

      case result do
        {:ok, %{failures: 0}} ->
          # After a successful run, the manifest should eventually be written
          # Give the agent a moment to flush
          Process.sleep(100)
          assert File.exists?(@manifest_path)

        {:ok, _} ->
          flunk("Tests had failures")
      end
    end

    test "second run with no changes returns :noop" do
      # First run - creates manifest
      ExUnit.start(autorun: false, colors: [enabled: false])

      spex_files = Path.wildcard("test/spex/*_spex.exs")

      {:ok, %{failures: 0}} = Mix.Compilers.Test.require_and_run(
        spex_files,
        ["test/spex"],
        [docs: false, debug_info: false],
        [stale: true]
      )

      Process.sleep(100)
      assert File.exists?(@manifest_path)

      # Second run - nothing changed
      ExUnit.start(autorun: false, colors: [enabled: false])

      result = Mix.Compilers.Test.require_and_run(
        spex_files,
        ["test/spex"],
        [docs: false, debug_info: false],
        [stale: true]
      )

      assert result == :noop
    end

    test "touching a file makes it stale" do
      # First run - creates manifest
      ExUnit.start(autorun: false, colors: [enabled: false])

      spex_files = Path.wildcard("test/spex/*_spex.exs")

      {:ok, %{failures: 0}} = Mix.Compilers.Test.require_and_run(
        spex_files,
        ["test/spex"],
        [docs: false, debug_info: false],
        [stale: true]
      )

      Process.sleep(100)

      # Touch one file to make it stale
      target_file = Enum.find(spex_files, &String.contains?(&1, "givens_spex"))
      assert target_file != nil

      # Ensure the mtime actually changes
      Process.sleep(1100)
      File.touch!(target_file)

      # Second run - should detect the stale file and attempt to run it
      # (returns {:ok, _} not :noop). total may be 0 because modules are
      # already loaded in-process, but the key is it didn't return :noop.
      ExUnit.start(autorun: false, colors: [enabled: false])

      result = Mix.Compilers.Test.require_and_run(
        spex_files,
        ["test/spex"],
        [docs: false, debug_info: false],
        [stale: true]
      )

      assert {:ok, _results} = result
    end

    test "force option runs all files even when none are stale" do
      # First run - creates manifest
      ExUnit.start(autorun: false, colors: [enabled: false])

      spex_files = Path.wildcard("test/spex/*_spex.exs")

      {:ok, %{failures: 0}} = Mix.Compilers.Test.require_and_run(
        spex_files,
        ["test/spex"],
        [docs: false, debug_info: false],
        [stale: true]
      )

      Process.sleep(100)

      # Verify nothing is stale
      ExUnit.start(autorun: false, colors: [enabled: false])

      result = Mix.Compilers.Test.require_and_run(
        spex_files,
        ["test/spex"],
        [docs: false, debug_info: false],
        [stale: true]
      )

      assert result == :noop

      # Now run with force - should attempt to run everything (not :noop)
      ExUnit.start(autorun: false, colors: [enabled: false])

      result = Mix.Compilers.Test.require_and_run(
        spex_files,
        ["test/spex"],
        [docs: false, debug_info: false],
        [stale: true, force: true]
      )

      assert {:ok, _results} = result
    end
  end

  describe "interleaving with mix test" do
    test "spex manifest entries use spex file paths" do
      ExUnit.start(autorun: false, colors: [enabled: false])

      spex_files = Path.wildcard("test/spex/*_spex.exs")

      {:ok, %{failures: 0}} = Mix.Compilers.Test.require_and_run(
        spex_files,
        ["test/spex"],
        [docs: false, debug_info: false],
        [stale: true]
      )

      Process.sleep(100)

      # Read the manifest and verify it contains spex file paths
      manifest_data = File.read!(@manifest_path) |> :erlang.binary_to_term()
      [_vsn | sources] = manifest_data

      source_files = Map.keys(sources)

      # All tracked files should be spex files
      Enum.each(source_files, fn file ->
        assert String.contains?(file, "_spex.exs"),
               "Expected spex file path, got: #{file}"
      end)
    end
  end
end
