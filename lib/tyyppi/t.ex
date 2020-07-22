defmodule Tyyppi.T do
  @moduledoc """
  Raw type wrapper. All the macros exported by that module are available in `Tyyppi`.
  Require and use `Tyyppi` instead.
  """

  alias Tyyppi.{Function, Matchers, Stats, T}

  require Logger

  @type kind :: :type | :remote_type | :user_type | :ann_type | :atom | :var
  @type visibility :: :typep | :type | :opaque
  @type simple ::
          nil
          | :a_function
          | :a_set
          | :abstract_expr
          | :af_atom
          | :af_clause
          | :af_lit_atom
          | :af_variable
          | :any
          | :atom
          | :binary
          | :boolean
          | :byte
          | :check_schedulers
          | :deflated
          | :des3_cbc
          | :filename
          | :filename_all
          | :fun
          | :idn
          | :input
          | :integer
          | :iovec
          | :iter
          | :iterator
          | :list
          | :map
          | :maybe_improper_list
          | :module
          | :non_neg_integer
          | :nonempty_list
          | :nonempty_string
          | :orddict
          | :pid
          | :pos_integer
          | :queue
          | :range
          | :receive
          | :record
          | :reference
          | :relation
          | :set
          | :string
          | :term
          | :tree
          | :tuple
          | :union

  @type nested ::
          {kind(), non_neg_integer(), simple()}
          | {kind(), non_neg_integer(), simple(), [nested()]}
  @type raw :: {kind(), non_neg_integer(), simple() | [nested()], [nested()]}

  @typedoc """
  The type information as it’s provided by _Elixir_.
  """
  @type t :: %__MODULE__{
          module: module(),
          source: binary(),
          type: visibility(),
          name: atom(),
          params: [nested()],
          definition: raw()
        }

  defstruct ~w|module source type name params definition|a

  defguard is_params(params) when is_list(params) or is_nil(params)

  defmacro parse({:|, _, [_, _]} = union) do
    quote bind_quoted: [union: Macro.escape(union)] do
      union
      |> T.union()
      |> T.parse_definition()
      |> Stats.type()
    end
  end

  defmacro parse({fun, _, params}) when is_atom(fun) and is_params(params) do
    quote bind_quoted: [fun: fun, params: params] do
      Stats.type({:type, 0, fun, params})
    end
  end

  defmacro parse({{:., _, [module, fun]}, _, params}) when is_params(params) do
    quote bind_quoted: [module: module, fun: fun, params: params || []] do
      Stats.type({module, fun, length(params)})
    end
  end

  defmacro parse({{:., _, [{:__aliases__, _, aliases}, fun]}, _, params})
           when is_params(params) do
    quote bind_quoted: [aliases: aliases, fun: fun, params: params || []] do
      Stats.type({Module.concat(aliases), fun, length(params)})
    end
  end

  defmacro parse(any) do
    quote bind_quoted: [any: Macro.escape(any)] do
      any
      |> T.parse_definition()
      |> Stats.type()
    end
  end

  @doc false
  def parse_quoted({:|, _, [_, _]} = union) do
    union
    |> T.union()
    |> T.parse_definition()
    |> Stats.type()
  end

  def parse_quoted({fun, _, params}) when is_atom(fun) and is_params(params) do
    Stats.type({:type, 0, fun, params})
  end

  def parse_quoted({{:., _, [{:__aliases__, _, aliases}, fun]}, _, params})
      when is_params(params) do
    Stats.type({Module.concat(aliases), fun, length(params)})
  end

  def parse_quoted({{:., _, [module, fun]}, _, params}) when is_params(params) do
    Stats.type({module, fun, length(params)})
  end

  def parse_quoted(any) do
    Logger.debug(inspect(any, label: "[🚰 T.parse_quoted/1]"))

    any
    |> T.parse_definition()
    |> Stats.type()
  end

  defmacro of?(type, term) do
    quote do
      %T{module: module, definition: definition} = T.parse(unquote(type))
      Matchers.of?(module, definition, unquote(term))
    end
  end

  defmacro apply(type, fun, args) do
    quote do
      %T{module: module, definition: definition} = T.parse(unquote(type))
      Function.apply(module, definition, unquote(fun), unquote(args))
    end
  end

  defmacro apply(fun, args) do
    quote do
      with %{module: module, name: fun, arity: arity} <-
             Map.new(Elixir.Function.info(unquote(fun))),
           {:ok, specs} <- Code.Typespec.fetch_specs(module),
           {{fun, arity}, [spec]} <- Enum.find(specs, &match?({{^fun, ^arity}, _}, &1)),
           do: Function.apply(module, spec, unquote(fun), unquote(args)),
           else: (result -> {:error, {:no_spec, result}})
    end
  end

  @doc false
  def parse_definition({fun, _meta, params}) when is_atom(fun) and is_params(params),
    do: {:type, 0, fun, params || []}

  def parse_definition(atom) when is_atom(atom), do: {:atom, 0, atom}

  def parse_definition(list) when is_list(list),
    do: {:type, 0, :union, Enum.map(list, &parse_definition/1)}

  def parse_definition(tuple) when is_tuple(tuple),
    do: {:type, 0, :tuple, tuple |> Tuple.to_list() |> Enum.map(&parse_definition/1)}

  @doc false
  def union(ast, acc \\ [])
  def union({:|, _, [t1, t2]}, acc), do: union(t2, [t1 | acc])
  def union(t, acc), do: Enum.reverse([t | acc])
end
