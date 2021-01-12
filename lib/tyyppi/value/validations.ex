defmodule Tyyppi.Value.Validations do
  @moduledoc false

  @spec void(any()) :: Tyyppi.Value.either()
  def void(value), do: {:ok, value}

  @spec non_neg_integer(value :: any()) :: Tyyppi.Value.either()
  def non_neg_integer(i) when i >= 0, do: {:ok, i}
  def non_neg_integer(_), do: {:error, "Must be greater or equal to zero"}

  @spec pos_integer(value :: any()) :: Tyyppi.Value.either()
  def pos_integer(i) when i > 0, do: {:ok, i}
  def pos_integer(_), do: {:error, "Must be greater than zero"}

  @spec timeout(value :: any()) :: Tyyppi.Value.either()
  def timeout(:infinity), do: {:ok, :infinity}
  def timeout(i) when i >= 0, do: {:ok, i}
  def timeout(_), do: {:error, "Must be integer, greater or equal to zero, or :infinity atom"}

  @spec mfa({m :: module(), f :: atom(), a :: non_neg_integer()}) :: Tyyppi.Value.either()
  def mfa({m, f, a}) do
    result =
      with {:module, ^m} <- Code.ensure_compiled(m),
           [_ | _] = funs <- m.__info__(:functions),
           {^f, ^a} <- Enum.find(funs, &match?({^f, ^a}, &1)),
           do: {:ok, {m, f, a}}

    result || {:error, "#{inspect(m)} does not declare a function #{f} of arity #{a}"}
  end

  def mfa(_), do: {:error, "Must be mfa()"}

  @spec mod_arg({m :: module(), args :: list()}) :: Tyyppi.Value.either()
  def mod_arg({m, args}),
    do: with({:module, ^m} <- Code.ensure_compiled(m), do: {:ok, {m, args}})

  def mod_arg(_), do: {:error, "Must be a tuple with module and argument list"}

  @spec fun(f :: (... -> any()), arity :: arity()) :: Tyyppi.Value.either()
  def fun(f, %{arity: arity}) when is_function(f, arity), do: {:ok, f}
  def fun(_, %{arity: arity}), do: {:error, "Expected a function of arity #{arity}"}
  def fun(f, _) when is_function(f), do: {:ok, f}
  def fun(_, _), do: {:error, "Expected a function"}
end
