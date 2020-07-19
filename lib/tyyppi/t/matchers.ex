defmodule Tyyppi.T.Matchers do
  @moduledoc false

  alias Tyyppi.T

  @type union :: [T.t()]

  def of?({:atom, _, term}, term) when is_atom(term), do: true

  def of?({:type, _, :term, []}, _term), do: true

  def of?({:type, _, :pid, []}, pid) when is_pid(pid), do: true

  def of?({:type, _, :tuple, type}, term)
      when is_list(type) and is_tuple(term) and length(type) == tuple_size(term) do
    type
    |> Enum.zip(Tuple.to_list(term))
    |> Enum.all?(fn {type, term} -> of?(type, term) end)
  end

  def of?({:type, _, :union, ts}, term),
    do: Enum.any?(ts, &of?(&1, term))

  def of?(_, _), do: false
end
