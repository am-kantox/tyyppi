defmodule Tyyppi.Matchers do
  @moduledoc false

  require Logger
  alias Tyyppi.Stats

  def of?(_module, {:atom, _, term}, term) when is_atom(term), do: true
  def of?(_module, {:integer, _, term}, term) when is_integer(term), do: true

  def of?(module, {:user_type, _, name, params}, term) do
    %{module: module, definition: definition} = Stats.type({module, name, length(params)})

    of?(module, definition, term)
  end

  def of?(_module, {:remote_type, _, [{:atom, 0, module}, {:atom, 0, name}, params]}, term) do
    %{module: module, definition: definition} = Stats.type({module, name, length(params)})

    of?(module, definition, term)
  end

  ###################### TYPES ######################

  #################### PRIMITIVES ###################

  def of?(_, {:type, _, :any, _}, _term), do: true
  def of?(_, {:type, _, :term, _}, _term), do: true

  def of?(_, {:type, _, :atom, _}, atom) when is_atom(atom), do: true
  def of?(_, {:type, _, :module, _}, atom) when is_atom(atom), do: true
  def of?(_, {:type, _, true, _}, true), do: true
  def of?(_, {:type, _, false, _}, false), do: true
  def of?(_, {:type, _, nil, _}, nil), do: true
  def of?(_, {:type, _, nil, _}, []), do: true
  def of?(_, {:type, _, :boolean, _}, bool) when is_boolean(bool), do: true
  def of?(_, {:type, _, :integer, _}, int) when is_integer(int), do: true
  def of?(_, {:type, _, :float, _}, flt) when is_float(flt), do: true
  def of?(_, {:type, _, :number, _}, num) when is_float(num) or is_integer(num), do: true
  def of?(_, {:type, _, :neg_integer, _}, i) when is_integer(i) and i < 0, do: true
  def of?(_, {:type, _, :pos_integer, _}, i) when is_integer(i) and i > 0, do: true
  def of?(_, {:type, _, :non_neg_integer, _}, i) when is_integer(i) and i >= 0, do: true
  def of?(_, {:type, _, :pid, _}, pid) when is_pid(pid), do: true
  def of?(_, {:type, _, :port, _}, port) when is_port(port), do: true
  def of?(_, {:type, _, :reference, _}, reference) when is_reference(reference), do: true

  ##################### LISTS #######################

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

  def of?(module, {:type, _, :keyword, []}, list), do: keyword?(module, list)

  ##################### BINARY ######################

  def of?(_module, {:type, _, :binary, []}, term) when is_binary(term), do: true
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

  ####################### FUN #######################

  def of?(_module, {:type, _, :->, [args, _result_type]}, fun)
      when is_function(fun, length(args)),
      do: true

  def of?(_module, {:type, _, :fun, [{:type, _, :product, args}, _result_type]}, fun)
      when is_function(fun, length(args)),
      do: true

  def of?(_module, {:type, _, :fun, [{:type, _, :any}, _result_type]}, fun)
      when is_function(fun),
      do: true

  ###################### MAPS #######################

  def of?(_, {:type, _, :map, []}, map) when is_map(map), do: true
  def of?(_, {:type, _, :map, :any}, map) when is_map(map), do: true

  def of?(module, {:type, _, :map, types}, term) when is_map(term),
    do: Enum.all?(types, &of?(module, &1, term))

  def of?(module, {:type, _, :map_field_exact, [{:atom, _, name}, type]}, term)
      when is_map(term),
      do: of?(module, type, Map.get(term, name))

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

  def of?(_module, {:type, _, :range, [{:integer, _, from}, {:integer, _, to}]}, term)
      when is_integer(term) and term in from..to,
      do: true

  def of?(module, {:type, _, :union, ts}, term),
    do: Enum.any?(ts, &of?(module, &1, term))

  #################### SINK ALL #####################

  def of?(module, definition, term) do
    Logger.debug("[🚰 Matchers.of?/3]: " <> inspect({module, definition, term}))
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

  defp keyword?(_module, list), do: Keyword.keyword?(list)
end
