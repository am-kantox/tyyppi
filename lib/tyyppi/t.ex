defmodule Tyyppi.T do
  @moduledoc """
  Raw type wrapper. All the macros exported by that module are available in `Tyyppi`.
  Require and use `Tyyppi` instead.
  """

  use Boundary, deps: [Tyyppi]

  alias Tyyppi.{Stats, T}

  require Logger

  @doc false
  defguardp is_params(params) when is_list(params) or is_atom(params)

  @typep kind :: :type | :remote_type | :user_type | :ann_type | :atom | :var
  @typep ast_lead :: :->
  @typep visibility :: :typep | :type | :opaque | :built_in
  @typep simple ::
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
           | :timeout
           | :tree
           | :tuple
           | :union

  @type ast :: Macro.t() | {module(), atom(), list() | nil | non_neg_integer()}
  @type raw :: {kind() | ast_lead(), non_neg_integer() | keyword(), simple() | [ast()], [raw()]}

  @typedoc """
  The type information in a human-readable format.

  For remote types, it’s gathered from
    [`Code.Typespec`](https://github.com/elixir-lang/elixir/blob/master/lib/elixir/lib/code/typespec.ex#L1),
    for built-in like `atom()` it’s simply constructed on the fly.
  """
  @type t(wrapped) :: %__MODULE__{
          type: visibility(),
          module: module(),
          name: atom(),
          params: [atom()],
          source: binary() | nil,
          definition: raw() | nil,
          quoted: wrapped
        }

  defstruct ~w|type module name params source definition quoted|a

  @spec loaded?(type :: T.t(wrapped)) :: boolean() when wrapped: term()
  @doc "Returns `true` if the type definition was loaded, `false` otherwise."
  def loaded?(%T{definition: nil}), do: false
  def loaded?(%T{}), do: true

  @spec parse_quoted({:| | {:., keyword(), list()} | atom(), keyword(), list() | nil}) ::
          Tyyppi.T.t(wrapped)
        when wrapped: term()
  @doc false
  def parse_quoted({:|, _, [_, _]} = union) do
    union
    |> union()
    |> parse_definition()
    |> Stats.type()
  end

  def parse_quoted({{:., _, [{:__aliases__, _, aliases}, fun]}, _, params})
      when is_params(params) do
    params = params |> normalize_params() |> length()
    Stats.type({Module.concat(aliases), fun, params})
  end

  def parse_quoted({{:., _, [module, fun]}, _, params}) when is_params(params) do
    params = params |> normalize_params() |> length()
    Stats.type({module, fun, params})
  end

  def parse_quoted({fun, _, params}) when is_atom(fun) and fun != :{} and is_params(params),
    do: Stats.type({:type, 0, fun, param_names(params)})

  def parse_quoted(any) do
    Logger.debug("[🚰 T.parse_quoted/1]: " <> inspect(any))

    any
    |> parse_definition()
    |> Stats.type()
  end

  @doc false
  def parse_definition(atom) when is_atom(atom), do: {:atom, 0, atom}

  def parse_definition(list) when is_list(list),
    do: {:type, 0, :union, Enum.map(list, &parse_definition/1)}

  def parse_definition(tuple) when is_tuple(tuple) do
    case Macro.decompose_call(tuple) do
      :error -> {:type, 0, :tuple, tuple |> decompose_tuple() |> Enum.map(&parse_definition/1)}
      {:{}, list} when is_list(list) -> {:type, 0, :tuple, Enum.map(list, &parse_definition/1)}
      _ -> parse_quoted(tuple).definition
    end
  end

  defp decompose_tuple({:{}, _, list}) when is_list(list), do: list
  defp decompose_tuple(tuple), do: Tuple.to_list(tuple)

  @doc false
  def union(ast, acc \\ [])
  def union({:|, _, [t1, t2]}, acc), do: union(t2, [t1 | acc])
  def union(t, acc), do: Enum.reverse([t | acc])

  @doc false
  @spec normalize_params([raw()] | any()) :: [raw()]
  def normalize_params(params) when is_list(params), do: params
  def normalize_params(_params), do: []

  @doc false
  @spec param_names([raw()] | any()) :: [atom()]
  def param_names(params) when is_list(params) do
    params
    |> Enum.reduce([], fn kv, acc ->
      case kv do
        {k, _} -> [k | acc]
        {k, _, _} -> [k | acc]
        _ -> acc
      end
    end)
    |> Enum.reverse()
  end

  def param_names(_), do: []

  # FIXME
  @doc false
  def collectable?(%Tyyppi.T{
        definition:
          {:type, _, :map,
           [{:type, _, :map_field_exact, [{:atom, _, :__struct__}, {:atom, _, _struct}]} | _]}
      }),
      do: false

  def collectable?(any), do: not is_nil(Collectable.impl_for(any))

  @doc false
  def enumerable?(%Tyyppi.T{
        definition:
          {:type, _, :map,
           [{:type, _, :map_field_exact, [{:atom, _, :__struct__}, {:atom, _, _struct}]} | _]}
      }),
      do: false

  def enumerable?(any), do: not is_nil(Enumerable.impl_for(any))

  defimpl String.Chars do
    @moduledoc false
    use Boundary, classify_to: Tyyppi.T

    defp stringify([]), do: ~s|[]|
    defp stringify({:atom, _, atom}) when atom in [nil, false, true], do: ~s|#{atom}|
    defp stringify({:atom, _, atom}), do: ~s|:#{atom}|
    defp stringify({:var, _, name}), do: ~s|_#{name}|
    defp stringify({:type, _, type}), do: ~s|#{type}()|

    defp stringify({:type, _, type, params}) do
      params = Enum.map_join(params, ", ", &stringify/1)
      ~s|#{type}(#{params})|
    end

    defp stringify({:remote_type, _, type}) when is_list(type),
      do: Enum.map_join(type, ", ", &stringify/1)

    defp stringify({:remote_type, _, type, params}) do
      params = Enum.map_join(params, ", ", &stringify/1)
      ~s|#{type}(#{params})|
    end

    defp stringify(any), do: inspect(any)

    def to_string(%T{module: nil, name: nil, definition: {:type, _, _type, _params} = type}),
      do: stringify(type)

    def to_string(%T{module: module, name: name, params: params}),
      do: stringify({:type, 0, "#{inspect(module)}.#{name}", params})
  end
end
