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
        params: [],
        quoted: {{:., [{:keep, {"lib/tyyppi/struct.ex", 68}}],
            [Test.Tyyppi.Struct.MyStruct, :my_type]},
          [{:keep, {"lib/tyyppi/struct.ex", 68}}], []},
        source: :user_type,
        type: :type
      }
  """
  @doc false
  defmacro defstruct(definition) when is_list(definition) do
    typespec = typespec(definition)

    quoted_types =
      quote location: :keep, bind_quoted: [definition: Macro.escape(definition)] do
        user_type = fn {type, _, _} ->
          __MODULE__
          |> Module.get_attribute(:type)
          |> Enum.find(&match?({_, {:"::", _, [{^type, _, _} | _]}, _}, &1))
          |> case do
            nil ->
              nil

            {kind, {:"::", _, [{type, _, params}, definition]}, _} ->
              params = T.normalize_params(params)
              param_names = T.param_names(params)

              %T{
                T.parse_quoted(definition)
                | type: kind,
                  module: __MODULE__,
                  name: type,
                  params: params,
                  source: :user_type,
                  quoted:
                    quote(do: unquote(__MODULE__).unquote(type)(unquote_splicing(param_names)))
              }
          end
        end

        Enum.map(definition, fn {key, type} ->
          {key, user_type.(type) || %T{quoted: type}}
        end)
      end

    quote do
      @quoted_types unquote(quoted_types)
      @fields Keyword.keys(@quoted_types)

      @typedoc ~s"""
      The type describing this struct. This type will be used to validate
        upserts when called via `Access` amd/or `#{inspect(__MODULE__)}.put/3`,
        `#{inspect(__MODULE__)}.update/4`.
      """
      @type t :: unquote(typespec)

      @doc ~s"""
      Returns the field types of this struct as keyword of
        `{field :: atom, type :: Tyyppi.T.t()}` pairs.
      """
      def types do
        Enum.map(@quoted_types, fn
          %T{definition: nil, quoted: quoted} -> Tyyppi.T.parse_quoted(quoted)
          user -> user
        end)
      end

      Kernel.defstruct(@fields)
    end
  end

  def typespec(types) do
    types =
      Enum.map(types, fn
        {k, type} when is_atom(type) ->
          {k, {type, [], []}}

        {k, {{_, _, _} = module, type}} ->
          {k, {{:., [], [module, type]}, [], []}}

        {k, {module, type}} when is_atom(module) and is_atom(type) ->
          modules = module |> Module.split() |> Enum.map(&:"#{&1}")
          {k, {{:., [], [{:__aliases__, [alias: false], modules}, type]}, [], []}}

        {k, v} ->
          {k, v}
      end)

    {:%{}, [], [{:__struct__, {:__MODULE__, [], Elixir}} | types]}
  end
end
