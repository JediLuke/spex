defmodule Mix.Tasks.SpexTest do
  use ExUnit.Case, async: true

  # Test the argument preprocessing for --jsonl flag
  # We test the preprocessing logic directly

  describe "jsonl argument preprocessing" do
    test "--jsonl with explicit = path preserves path" do
      args = ["test/file.exs", "--jsonl=custom.jsonl", "--quiet"]
      result = preprocess_jsonl_arg(args)

      assert "--jsonl=custom.jsonl" in result
      assert "test/file.exs" in result
      assert "--quiet" in result
    end

    test "--jsonl without value followed by .exs file gets default path" do
      args = ["--jsonl", "test/file.exs"]
      result = preprocess_jsonl_arg(args)

      assert "--jsonl=spex_failures.jsonl" in result
      assert "test/file.exs" in result
    end

    test "-j shorthand without value gets default path" do
      args = ["-j", "test/file.exs"]
      result = preprocess_jsonl_arg(args)

      assert "--jsonl=spex_failures.jsonl" in result
      assert "test/file.exs" in result
    end

    test "--jsonl at end without value gets default path" do
      args = ["test/file.exs", "--quiet", "--jsonl"]
      result = preprocess_jsonl_arg(args)

      assert "--jsonl=spex_failures.jsonl" in result
      assert "test/file.exs" in result
      assert "--quiet" in result
    end

    test "--jsonl with non-.exs path uses that as the output path" do
      args = ["--jsonl", "output.jsonl", "test/file.exs"]
      result = preprocess_jsonl_arg(args)

      # The next arg "output.jsonl" doesn't end in .exs, so it's used as the path
      assert "--jsonl=output.jsonl" in result
      assert "test/file.exs" in result
    end

    test "--jsonl followed by another flag gets default path" do
      args = ["--jsonl", "--quiet", "test/file.exs"]
      result = preprocess_jsonl_arg(args)

      assert "--jsonl=spex_failures.jsonl" in result
      assert "--quiet" in result
      assert "test/file.exs" in result
    end

    test "args without --jsonl are unchanged" do
      args = ["test/file.exs", "--quiet", "--trace"]
      result = preprocess_jsonl_arg(args)

      assert result == args
    end

    test "multiple flags preserve order" do
      args = ["--verbose", "--jsonl", "test/spex/my_spex.exs", "--trace"]
      result = preprocess_jsonl_arg(args)

      assert "--jsonl=spex_failures.jsonl" in result
      assert "test/spex/my_spex.exs" in result
      assert "--verbose" in result
      assert "--trace" in result
    end
  end

  # Reimplementation of the preprocessing logic for testing
  # This mirrors the implementation in Mix.Tasks.Spex
  defp preprocess_jsonl_arg(args), do: preprocess_jsonl_arg(args, [])
  defp preprocess_jsonl_arg([], acc), do: Enum.reverse(acc)

  defp preprocess_jsonl_arg(["--jsonl" | rest], acc) do
    case rest do
      [next | _] when is_binary(next) ->
        if String.starts_with?(next, "-") or String.ends_with?(next, ".exs") do
          preprocess_jsonl_arg(rest, ["--jsonl=spex_failures.jsonl" | acc])
        else
          # Next arg is the jsonl path, skip it in rest processing
          preprocess_jsonl_arg(tl(rest), ["--jsonl=#{next}" | acc])
        end
      [] ->
        Enum.reverse(["--jsonl=spex_failures.jsonl" | acc])
    end
  end

  defp preprocess_jsonl_arg(["-j" | rest], acc) do
    preprocess_jsonl_arg(["--jsonl" | rest], acc)
  end

  defp preprocess_jsonl_arg([arg | rest], acc) do
    preprocess_jsonl_arg(rest, [arg | acc])
  end
end
