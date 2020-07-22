defmodule Tyyppi.Function do
  @moduledoc false

  import Tyyppi.Matchers, only: [of?: 3]

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
end
