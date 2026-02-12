defmodule SexySpex.Runtime do
  @moduledoc false

  @doc false
  def execute_given(module, name, context) do
    if name in module.__givens__() do
      module.__call_given__(name, context)
    else
      imported = module.__imported_givens_modules__()

      result =
        Enum.find_value(imported, fn mod ->
          Code.ensure_loaded(mod)

          if function_exported?(mod, :__givens__, 0) and
               function_exported?(mod, :__call_given__, 2) do
            if name in mod.__givens__() do
              {:found, mod.__call_given__(name, context)}
            end
          end
        end)

      case result do
        {:found, value} ->
          value

        nil ->
          raise ArgumentError, """
          No given registered with name #{inspect(name)}.

          Make sure you have defined it with:

              given #{inspect(name)} do
                # setup code
                {:ok, %{key: value}}
              end

          Or imported it from another module with:

              import_givens MyModule
          """
      end
    end
  end

  @doc false
  def process_step_result(result, current_context) do
    case result do
      :ok ->
        current_context

      {:ok, %{} = new_context} ->
        new_context

      other ->
        raise ArgumentError, """
        Step must return :ok or {:ok, context}.
        Got: #{inspect(other)}

        Valid examples:
          :ok                                    # Keep context unchanged
          {:ok, context}                         # Return updated context
          {:ok, Map.put(context, :key, value)}   # Return modified context
        """
    end
  end

  @doc false
  def process_context_step_result(step_type, description, result) do
    case result do
      {:ok, %{} = new_context} ->
        new_context

      :ok ->
        raise ArgumentError, """
        #{step_type} "#{description}" returned :ok, but context-receiving steps must return {:ok, context}.

        Bare :ok would silently discard context. Change:

            #{String.downcase(step_type)}_ "#{description}", context do
              ...
              :ok
            end

        To:

            #{String.downcase(step_type)}_ "#{description}", context do
              ...
              {:ok, context}
            end
        """

      other ->
        raise ArgumentError, """
        #{step_type} "#{description}" must return {:ok, context}.
        Got: #{inspect(other)}

        Valid examples:
          {:ok, context}                         # Return context unchanged
          {:ok, Map.put(context, :key, value)}   # Return modified context
        """
    end
  end
end
