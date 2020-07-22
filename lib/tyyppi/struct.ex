defmodule Tyyppi.Struct do
  import Kernel, except: [defstruct: 1]

  alias Tyyppi.T
  require T

  @moduledoc """
  Creates the typed struct with spec bound to each field.

  _Example:_

      iex> defmodule MyStruct do
      ...>   @type my_type :: :ok | {:error, term()}
      ...>   Tyyppi.Struct.defstruct foo: atom(), bar: GenServer.on_start(), baz: my_type()
      ...> end
      iex> types = MyStruct.types()
      ...> types[:foo]
      %Tyyppi.T{
        definition: {:type, 0, :atom, []},
        module: nil,
        name: nil,
        params: [],
        source: nil,
        type: :built_in
      }
      ...> types[:baz]
      %Tyyppi.T{
        definition: {:type, 0, :union, [
          {:atom, 0, :ok},
          {:type, 0, :tuple, [
            {:atom, 0, :error}, {:type, 0, :term, []}]}]},
        module: Test.Tyyppi.Struct.MyStruct,
        name: :my_type,
        params: nil,
        source: nil,
        type: :type
      }
  """
  @doc false
  defmacro defstruct(definition) when is_list(definition) do
    types =
      quote bind_quoted: [definition: Macro.escape(definition)] do
        user_type = fn {type, _, _} ->
          __MODULE__
          |> Module.get_attribute(:type)
          |> Enum.find(&match?({_, {:"::", _, [{^type, _, _} | _]}, _}, &1))
          |> case do
            nil ->
              nil

            {kind, {:"::", _, [{type, _, params}, definition]}, _} ->
              %T{
                T.parse_quoted(definition)
                | type: kind,
                  name: type,
                  params: params,
                  module: __MODULE__,
                  source: nil
              }
          end
        end

        Enum.map(definition, fn {key, type} ->
          {key, user_type.(type) || T.parse_quoted(type)}
        end)
      end

    quote do
      @types unquote(types)
      @fields Keyword.keys(@types)

      def types, do: @types
      Kernel.defstruct(@fields)
    end
  end
end