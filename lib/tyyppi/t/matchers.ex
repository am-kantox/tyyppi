defmodule Tyyppi.T.Matchers do
  @moduledoc false

  alias Tyyppi.T

  @type union :: [T.t()]

  def of?(_module, {:atom, _, term}, term) when is_atom(term), do: true

  def of?(module, {:user_type, _, name, params}, term) do
    %{module: module, definition: definition} = Tyyppi.Stats.type({module, name, length(params)})

    of?(module, definition, term)
  end

  def of?(_module, {:remote_type, _, [{:atom, 0, module}, {:atom, 0, name}, params]}, term) do
    %{module: module, definition: definition} = Tyyppi.Stats.type({module, name, length(params)})

    of?(module, definition, term)
  end

  ###################### TYPES ######################

  #################### PRIMITIVES ###################

  def of?(_, {:type, _, :any, []}, _term), do: true
  def of?(_, {:type, _, :term, []}, _term), do: true

  def of?(_, {:type, _, :atom, []}, atom) when is_atom(atom), do: true
  def of?(_, {:type, _, true, []}, true), do: true
  def of?(_, {:type, _, false, []}, false), do: true
  def of?(_, {:type, _, nil, []}, nil), do: true
  def of?(_, {:type, _, nil, []}, []), do: true
  def of?(_, {:type, _, :integer, []}, int) when is_integer(int), do: true
  def of?(_, {:type, _, :float, []}, flt) when is_float(flt), do: true
  def of?(_, {:type, _, :number, []}, num) when is_float(num) or is_integer(num), do: true
  def of?(_, {:type, _, :neg_integer, []}, i) when is_integer(i) and i < 0, do: true
  def of?(_, {:type, _, :pos_integer, []}, i) when is_integer(i) and i > 0, do: true
  def of?(_, {:type, _, :non_neg_integer, []}, i) when is_integer(i) and i >= 0, do: true
  def of?(_, {:type, _, :pid, []}, pid) when is_pid(pid), do: true
  def of?(_, {:type, _, :port, []}, port) when is_port(port), do: true
  def of?(_, {:type, _, :reference, []}, reference) when is_reference(reference), do: true
  def of?(_, {:type, _, :map, []}, map) when is_map(map), do: true
  def of?(module, {:type, _, :list, [type]}, list), do: proper_list?(module, list, type)

  def of?(module, {:type, n, :list, []}, list),
    do: of?(module, {:type, n, :list, [{:type, 0, :any, []}]}, list)

  def of?(module, {:type, _, :nonempty_list, [type]}, list)
      when is_list(list) and length(list) > 0,
      do: proper_list?(module, list, type)

  def of?(module, {:type, _, :maybe_improper_list, [ht, tt]}, list),
    do: improper_list?(module, list, ht, tt, true, true)

  def of?(module, {:type, _, :nonempty_improper_list, [ht, tt]}, list),
    do: improper_list?(module, list, ht, tt, false, false)

  def of?(module, {:type, _, :nonempty_maybe_improper_list, [ht, tt]}, list),
    do: improper_list?(module, list, ht, tt, true, false)

  def of?(module, {:type, _, :tuple, type}, term)
      when is_list(type) and is_tuple(term) and length(type) == tuple_size(term) do
    type
    |> Enum.zip(Tuple.to_list(term))
    |> Enum.all?(fn {type, term} -> of?(module, type, term) end)
  end

  def of?(_module, {:type, _, :binary, [{:integer, _, 0}, {:integer, _, 0}]}, ""), do: true

  def of?(_module, {:type, _, :binary, [{:integer, _, n}, {:integer, _, 0}]}, term)
      when is_binary(term) and byte_size(term) == n,
      do: true

  def of?(_module, {:type, _, :binary, [{:integer, _, 0}, {:integer, _, n}]}, term)
      when is_bitstring(term) and ceil(bit_size(term) / n) == bit_size(term) / n,
      do: true

  def of?(_module, {:type, _, :binary, [{:integer, _, ns}, {:integer, _, nu}]}, term)
      when ns > 0 and nu > 0 and is_bitstring(term) and bit_size(term) == ns * nu,
      do: true

  ###################### MAPS #######################

  def of?(module, {:type, _, :map, types}, term) when is_map(term),
    do: Enum.all?(types, &of?(module, &1, term))

  def of?(module, {:type, _, :map_field_exact, [{:atom, _, name}, type]}, term)
      when is_map(term) do
    of?(module, type, Map.get(term, name))
  end

  def of?(module, {:type, _, :map_field_exact, [{:type, _, _, _} = key_type, value_type]}, term)
      when is_map(term) and map_size(term) > 0 do
    Enum.all?(term, fn {k, v} ->
      of?(module, key_type, k) and of?(module, value_type, v)
    end)
  end

  def of?(module, {:type, _, :map_field_assoc, [{:type, _, _, _} = key_type, value_type]}, term)
      when is_map(term) do
    Enum.all?(term, fn {k, v} ->
      of?(module, key_type, k) and of?(module, value_type, v)
    end)
  end

  ###################### UNION ######################

  def of?(module, {:type, _, :union, ts}, term),
    do: Enum.any?(ts, &of?(module, &1, term))

  #################### SINK ALL #####################

  def of?(module, definition, term) do
    IO.inspect({module, definition, term}, label: "UNMATCHED")
    false
  end

  ###################################################

  defp proper_list?(_module, [], _t), do: true

  defp proper_list?(module, [h | t], tt) when is_list(t),
    do: of?(module, tt, h) and proper_list?(module, t, tt)

  defp proper_list?(_module, _, _t), do: false

  defp improper_list?(_module, [], _ht, _tt, maybe?, empty?), do: maybe? and empty?

  defp improper_list?(module, [h | t], ht, tt, maybe?, _empty?) when is_list(t),
    do: of?(module, ht, h) and improper_list?(module, t, ht, tt, maybe?, true)

  defp improper_list?(module, [_ | t], _ht, tt, _maybe?, _empty?), do: of?(module, tt, t)
  defp improper_list?(_module, _, _ht, _tt, _maybe?, _empty?), do: false
end
