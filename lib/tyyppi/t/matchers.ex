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

  def of?(_module, {:type, _, :term, []}, _term), do: true

  def of?(_module, {:type, _, :atom, []}, atom) when is_atom(atom), do: true
  def of?(_module, {:type, _, :integer, []}, int) when is_integer(int), do: true
  def of?(_module, {:type, _, :float, []}, flt) when is_float(flt), do: true

  def of?(_module, {:type, _, :non_neg_integer, []}, int) when is_integer(int) and int >= 0,
    do: true

  def of?(_module, {:type, _, :pid, []}, pid) when is_pid(pid), do: true

  def of?(module, {:type, _, :tuple, type}, term)
      when is_list(type) and is_tuple(term) and length(type) == tuple_size(term) do
    type
    |> Enum.zip(Tuple.to_list(term))
    |> Enum.all?(fn {type, term} -> of?(module, type, term) end)
  end

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

  def of?(_, _, _), do: false
end
