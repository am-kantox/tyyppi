defmodule Tyyppi.Value.Generations do
  @moduledoc false

  alias StreamData, as: SD

  def any, do: SD.term()

  def atom, do: atom(:alphanumeric)
  def atom(kind) when is_atom(kind), do: SD.atom(kind)

  def string, do: SD.binary()
  def string(options) when is_list(options), do: SD.binary(options)

  def boolean, do: SD.boolean()

  def integer, do: integer()
  def integer(_.._ = range), do: SD.integer(range)

  def non_neg_integer, do: SD.map(SD.integer(), &abs(&1))
  def non_neg_integer(top) when is_integer(top) and top > 0, do: integer(0..top)

  def pos_integer, do: SD.positive_integer()

  def pos_integer(top) when is_integer(top) and top > 0,
    do: 0..top |> integer() |> SD.filter(&(&1 > 0))

  def timeout, do: SD.one_of([non_neg_integer(), SD.constant(:infinity)])

  def timeout(top) when is_integer(top) and top > 0,
    do: SD.one_of([integer(0..top), SD.constant(:infinity)])

  def pid, do: pid(0..4096)

  def pid(l..r) do
    SD.bind(SD.constant(0), fn p1 ->
      SD.bind(SD.integer(l..r), fn p2 ->
        SD.bind(SD.integer(l..r), fn p3 ->
          SD.constant(Tyyppi.Value.pid(p1, p2, p3))
        end)
      end)
    end)
  end

  def mfa(options \\ [])
  def mfa(%{} = options), do: options |> Map.to_list() |> mfa()

  def mfa(options) do
    max_arity = Keyword.get(options, :max_arity, 12)
    existing = Keyword.get(options, :existing, false)

    SD.bind(SD.atom(:alias), fn mod ->
      SD.bind(SD.atom(:alphanumeric), fn fun ->
        SD.bind(SD.integer(0..max_arity), fn arity ->
          SD.constant(Tyyppi.Value.mfa(value: {mod, fun, arity}, existing: existing))
        end)
      end)
    end)
  end

  def mod_arg(options \\ [])
  def mod_arg(%{} = options), do: options |> Map.to_list() |> mod_arg()

  def mod_arg(options) do
    args_generator = Keyword.get(options, :args_gen, SD.list_of(SD.term()))
    max_args_length = Keyword.get(options, :args_len, 12)
    existing = Keyword.get(options, :existing, false)

    SD.bind(SD.atom(:alias), fn mod ->
      SD.bind(SD.list_of(args_generator, max_length: max_args_length), fn params ->
        SD.constant(Tyyppi.Value.mod_arg(value: {mod, params}, existing: existing))
      end)
    end)
  end

  defmodule FunStubs do
    Enum.each(0..12, fn arity ->
      args = Macro.generate_arguments(arity, __MODULE__)
      def f(unquote_splicing(args)), do: :ok
    end)
  end

  def fun(options \\ [])
  def fun(%{} = options), do: options |> Map.to_list() |> fun()

  def fun(options) do
    options
    |> Keyword.get(:arity, Enum.to_list(0..12))
    |> List.wrap()
    |> Enum.map(&Function.capture(FunStubs, :f, &1))
    |> Enum.map(&Tyyppi.Value.fun/1)
    |> Enum.map(&SD.constant/1)
    |> SD.one_of()
  end

  def one_of(options \\ [])
  def one_of(%{} = options), do: options |> Map.to_list() |> one_of()

  def one_of(options) do
    options
    |> Keyword.get(:allowed, [])
    |> Enum.map(&Tyyppi.Value.one_of/1)
    |> Enum.map(&SD.constant/1)
    |> SD.one_of()
  end

  def formulae(_options), do: raise("Not Implemented")
  def list(_options), do: raise("Not Implemented")
  def struct(_options), do: raise("Not Implemented")
end
