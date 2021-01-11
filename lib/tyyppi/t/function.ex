defmodule Tyyppi.Function do
  @moduledoc false

  import Tyyppi.Matchers, only: [of?: 3]

  def apply(module, {:type, _, :bounded_fun, [fun_type, constraint]}, fun, args) do
    type = apply_contraints(fun_type, constraint)
    apply(module, type, fun, args)
  end

  def apply(
        module,
        {:type, _, :fun, [{:type, _, :product, arg_types}, result_type]} = type,
        fun,
        args
      ) do
    with(
      {true, _} <- {of?(module, type, fun), {:error, {:fun, fun}}},
      {true, _} <- {length(args) == length(arg_types), {:error, {:arity, length(args)}}},
      {true, _} <-
        {arg_types
         |> Enum.zip(args)
         |> Enum.all?(fn {type, term} -> of?(module, type, term) end), {:error, {:args, args}}},
      result <- apply(fun, args),
      {true, _} <- {of?(module, result_type, result), {:error, {:result, result}}},
      do: {true, {:ok, result}}
    )
    |> elem(1)
  end

  def apply(
        module,
        {:type, _, :fun, [{:type, _, :any}, result_type]} = type,
        fun,
        args
      ) do
    with(
      {true, _} <- {of?(module, type, fun), {:error, {:fun, fun}}},
      {true, _} <- {is_function(fun, length(args)), {:error, {:arity, length(args)}}},
      result <- apply(fun, args),
      {true, _} <- {of?(module, result_type, result), {:error, {:result, result}}},
      do: {true, {:ok, result}}
    )
    |> elem(1)
  end

  # {:type, 1141, :fun, [{:type, 1141, :product, [{:var, 1141, :Integer}]}, {:type, 1141, :binary, []}]}
  # {:type, 1142, :constraint, [{:atom, 1142, :is_subtype}, [{:var, 1142, :Integer}, {:type, 1142, :integer, []}]]}
  defp apply_contraints({:type, x, :fun, types}, constraints) do
    types =
      Enum.map(types, fn type ->
        case type do
          {:type, x, y, vars} ->
            vars =
              Enum.map(vars, fn var ->
                case var do
                  {:var, _, var} ->
                    List.first(
                      for {:type, _, :constraint, [_, [{:var, _, ^var}, type]]} <- constraints,
                          do: type
                    )

                  other ->
                    other
                end
              end)

            {:type, x, y, vars}

          other ->
            other
        end
      end)

    {:type, x, :fun, types}
  end
end
