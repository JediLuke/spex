defmodule SexySpex.Runtime do
  @moduledoc false

  @doc false
  def process_step_result({:ok, %{} = new_context}, _description), do: new_context

  def process_step_result(other, description) do
    raise ArgumentError, """
    Step #{inspect(description)} must return {:ok, context}.
    Got: #{inspect(other)}

    Every step block — given_, when_, then_, and_, and registered givens —
    must return {:ok, context}. Bare :ok is not allowed; if a step doesn't
    change context, return {:ok, context} explicitly.
    """
  end
end
