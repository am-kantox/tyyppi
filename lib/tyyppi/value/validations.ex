defmodule Tyyppi.Value.Validations do
  @moduledoc false

  @spec any(any()) :: Tyyppi.Value.either()
  def any(value), do: {:ok, value}

  @spec non_neg_integer(value :: integer()) :: Tyyppi.Value.either()
  def non_neg_integer(i) when i >= 0, do: {:ok, i}
  def non_neg_integer(_), do: {:error, "Must be greater or equal to zero"}

  @spec pos_integer(value :: integer()) :: Tyyppi.Value.either()
  def pos_integer(i) when i > 0, do: {:ok, i}
  def pos_integer(_), do: {:error, "Must be greater than zero"}

  @spec timeout(value :: timeout()) :: Tyyppi.Value.either()
  def timeout(:infinity), do: {:ok, :infinity}
  def timeout(i) when i >= 0, do: {:ok, i}
  def timeout(_), do: {:error, "Must be integer, greater or equal to zero, or :infinity atom"}

  @spec pid(pid :: pid()) :: Tyyppi.Value.either()
  def pid(pid) when is_pid(pid), do: {:ok, pid}
  def pid(_), do: {:error, "Must be a `pid()`"}

  @spec mfa({m :: module(), f :: atom(), a :: non_neg_integer()}, %{existing: boolean()}) ::
          Tyyppi.Value.either()
  def mfa({m, f, a}, %{existing: existing}) do
    if existing do
      with {:module, ^m} <- Code.ensure_compiled(m),
           [_ | _] = funs <- m.module_info[:exports],
           {^f, ^a} <- Enum.find(funs, &match?({^f, ^a}, &1)),
           do: {:ok, {m, f, a}},
           else: (_ -> {:error, "#{inspect(m)} does not declare a function #{f} of arity #{a}"})
    else
      if is_atom(m) and is_atom(f) and is_integer(a) and a >= 0,
        do: {:ok, {m, f, a}},
        else: {:error, "Expected an MFA in the form `{m, f, a}`"}
    end
  end

  def mfa({m, f, a}, _), do: mfa({m, f, a}, %{existing: false})

  @spec mod_arg({m :: module(), args :: list()}, %{existing: boolean()}) :: Tyyppi.Value.either()
  def mod_arg({m, args}, %{existing: true}),
    do: with({:module, ^m} <- Code.ensure_compiled(m), do: {:ok, {m, args}})

  def mod_arg({m, args}, _) when is_atom(m) and is_list(args), do: {:ok, {m, args}}

  @spec fun(f :: (... -> any()), %{arity: arity()}) :: Tyyppi.Value.either()
  def fun(f, %{arity: arity}) when is_function(f, arity), do: {:ok, f}

  def fun(f, %{arity: arity}) when is_function(f),
    do: {:error, "Expected a function of arity #{arity}"}

  def fun(f, _) when is_function(f), do: {:ok, f}

  @spec one_of(any(), %{allowed: list()}) :: Tyyppi.Value.either()
  def one_of(item, %{allowed: allowed}),
    do:
      if(item in allowed,
        do: {:ok, item},
        else: {:error, "Expected a value to be one of " <> inspect(allowed)}
      )

  @spec list(list(), %{type: Tyyppi.T.t()}) :: Tyyppi.Value.either()
  def list(list, %{type: type}) do
    case Enum.split_with(list, &Tyyppi.of_type?(type, &1)) do
      {list, []} ->
        {:ok, list}

      {_, errored} ->
        {:error, "Expected all elements to be of type #{type}. Failed: " <> inspect(errored)}
    end
  end

  if Code.ensure_loaded?(Formulae) do
    @spec formulae(any(), %{formulae: Formulae.t() | {module(), atom(), list()}}) ::
            Tyyppi.Value.either()

    def formulae(value, %{formulae: %Formulae{} = formulae}) do
      {:ok, formulae.eval.(value: value)}
    rescue
      e in [Formulae.SyntaxError, Formulae.RunnerError] ->
        {:error, e.message}
    end
  else
    @spec formulae(any(), %{formulae: {module(), atom(), list()}}) :: Tyyppi.Value.either()
  end

  def formulae(value, %{formulae: {mod, fun, args}}) do
    case apply(mod, fun, [value | args]) do
      {:ok, value} -> {:ok, value}
      {:error, message} -> {:error, message}
      value -> {:ok, value}
    end
  end

  @spec struct(struct()) :: Tyyppi.Value.either()
  def struct(%ts{} = struct) do
    if ts.__info__(:functions)[:validate] == 1,
      do: ts.validate(struct),
      else: {:error, "The given struct does not respond to `validate/1`"}
  end
end
