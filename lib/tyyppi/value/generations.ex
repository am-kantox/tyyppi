defmodule Tyyppi.Value.Generations do
  @moduledoc false

  alias StreamData, as: SD

  def any(), do: SD.term()

  def atom(), do: atom(:alphanumeric)
  def atom(kind) when is_atom(kind), do: SD.atom(kind)

  def string(), do: SD.binary()
  def string(options) when is_list(options), do: SD.binary(options)

  def boolean(), do: SD.boolean()

  def integer(), do: integer()
  def integer(_.._ = range), do: SD.integer(range)

  def non_neg_integer(), do: SD.map(SD.integer(), &abs(&1))
  def non_neg_integer(top) when is_integer(top) and top > 0, do: integer(0..top)

  def pos_integer(), do: SD.positive_integer()

  def pos_integer(top) when is_integer(top) and top > 0,
    do: 0..top |> integer() |> SD.filter(&(&1 > 0))

  def timeout(), do: SD.one_of([non_neg_integer(), SD.constant(:infinity)])

  def timeout(top) when is_integer(top) and top > 0,
    do: SD.one_of([integer(0..top), SD.constant(:infinity)])

  def pid(), do: pid(0..4096)

  def pid(l..r) do
    SD.bind(SD.constant(0), fn p1 ->
      SD.bind(SD.integer(l..r), fn p2 ->
        SD.bind(SD.integer(l..r), fn p3 ->
          SD.constant(Tyyppi.Value.pid(p1, p2, p3))
        end)
      end)
    end)
  end

  def mfa(options) do
    SD.bind(SD.atom(:alias), fn mod ->
      SD.bind(SD.atom(:alphanumeric), fn fun ->
        SD.bind(SD.integer(0..12), fn arity ->
          SD.constant(Tyyppi.Value.mfa(mod, fun, arity))
        end)
      end)
    end)
  end
end
