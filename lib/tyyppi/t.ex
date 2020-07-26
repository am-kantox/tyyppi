defmodule Tyyppi.T do
  @moduledoc """
  Raw type wrapper. All the macros exported by that module are available in `Tyyppi`.
  Require and use `Tyyppi` instead.
  """

  alias Tyyppi.{Function, Matchers, Stats, T}

  require Logger

  @typep kind :: :type | :remote_type | :user_type | :ann_type | :atom | :var
  @typep visibility :: :typep | :type | :opaque
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
           | :tree
           | :tuple
           | :union

  @type ast :: Macro.t()
  @type raw :: {kind(), non_neg_integer(), simple() | [ast()], [ast()]}

  @typedoc """
  The type information in a human-readable format.

  For remote types, it’s gathered from `Code.Typespec`, for built-in like `atom()`
    ot’s simply constructed on the fly.
  """
  @type t :: %__MODULE__{
          type: visibility(),
          module: module(),
          name: atom(),
          params: [atom()],
          source: binary(),
          definition: raw() | nil,
          quoted: ast()
        }

  defstruct ~w|type module name params source definition quoted|a

  @doc false
  defguard is_params(params) when is_list(params) or is_atom(params)

  @spec loaded?(type :: T.t()) :: boolean()
  @doc "Returns `true` if the type definition was loaded, `false` otherwise."
  def loaded?(%T{definition: nil}), do: false
  def loaded?(%T{}), do: true

  @doc """
  Parses the type as by spec and returns its `Tyyppi.T` representation.

  _Example:_

      iex> require Tyyppi.T
      ...> Tyyppi.T.parse(GenServer.on_start()) |> Map.put(:source, nil)
      %Tyyppi.T{
        definition: {:type, 700, :union,
        [
          {:type, 0, :tuple, [{:atom, 0, :ok}, {:type, 700, :pid, []}]},
          {:atom, 0, :ignore},
          {:type, 0, :tuple,
            [
              {:atom, 0, :error},
              {:type, 700, :union,
              [
                {:type, 0, :tuple,
                  [{:atom, 0, :already_started}, {:type, 700, :pid, []}]},
                {:type, 700, :term, []}
              ]}
            ]}
        ]},
        module: GenServer,
        name: :on_start,
        params: [],
        source: nil,
        quoted: {{:., [], [GenServer, :on_start]}, [], []},
        type: :type
      }
  """
  defmacro parse({:|, _, [_, _]} = type) do
    quote bind_quoted: [union: Macro.escape(type)] do
      union
      |> T.union()
      |> T.parse_definition()
      |> Stats.type()
    end
  end

  defmacro parse([{:->, _, [args, result]}]) do
    type =
      case args do
        [{:..., _, _}] -> {:type, 0, :any}
        args -> {:type, 0, :product, Enum.map(args, &parse_definition/1)}
      end

    result = parse_definition(result)

    quote bind_quoted: [type: Macro.escape(type), result: Macro.escape(result)] do
      Stats.type({:type, 0, :fun, [type, result]})
    end
  end

  defmacro parse({{:., _, [module, fun]}, _, params}) when is_params(params) do
    params = params |> normalize_params() |> length()

    quote bind_quoted: [module: module, fun: fun, params: params] do
      Stats.type({module, fun, params})
    end
  end

  defmacro parse({{:., _, [{:__aliases__, _, aliases}, fun]}, _, params})
           when is_params(params) do
    params = params |> normalize_params() |> length()

    quote bind_quoted: [aliases: aliases, fun: fun, params: params] do
      Stats.type({Module.concat(aliases), fun, params})
    end
  end

  defmacro parse({fun, _, params}) when is_atom(fun) and is_params(params) do
    quote bind_quoted: [fun: fun, params: param_names(params)] do
      Stats.type({:type, 0, fun, params})
    end
  end

  defmacro parse(any) do
    Logger.debug("[🚰 T.parse/1]: " <> inspect(any))

    quote bind_quoted: [any: Macro.escape(any)] do
      any
      |> T.parse_definition()
      |> Stats.type()
    end
  end

  @spec parse_quoted({:| | {:., keyword(), list()} | atom(), keyword(), list() | nil}) ::
          Tyyppi.T.t()
  @doc false
  def parse_quoted({:|, _, [_, _]} = union) do
    union
    |> T.union()
    |> T.parse_definition()
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

  def parse_quoted({fun, _, params}) when is_atom(fun) and is_params(params) do
    Stats.type({:type, 0, fun, param_names(params)})
  end

  def parse_quoted(any) do
    Logger.debug("[🚰 T.parse_quoted/1]: " <> inspect(any))

    any
    |> T.parse_definition()
    |> Stats.type()
  end

  @doc """
  Returns `true` if the `term` passed as the second parameter is of type `type`.

  _Examples:_

      iex> require Tyyppi.T
      ...> Tyyppi.T.of?(atom(), :ok)
      true
      ...> Tyyppi.T.of?(atom(), 42)
      false
      ...> Tyyppi.T.of?(GenServer.on_start(), {:error, {:already_started, self()}})
      true
      ...> Tyyppi.T.of?(GenServer.on_start(), :foo)
      false
  """
  defmacro of?(type, term) do
    quote do
      %T{module: module, definition: definition} = T.parse(unquote(type))
      Matchers.of?(module, definition, unquote(term))
    end
  end

  @doc """
  **Experimental:** applies the **external** function given as an argument
    in the form `&Module.fun/arity` or **anonymous** function with arguments.
    Validates the arguments given and the result produced by the call.

  Only named types are supported at the moment.

  If the number of arguments does not fit the arity of the type, returns
    `{:error, {:arity, n}}` where `n` is the number of arguments passed.

  If arguments did not pass the validation, returns `{:error, {:args, [arg1, arg2, ...]}}`
    where `argN` are the arguments passed.

  If both arity and types of arguments are ok, _evaluates_ the function and checks the
    result against the type. Returns `{:ok, result}` _or_ `{:error, {:result, result}}`
    if the validation did not pass.

  _Example:_

  ```elixir
  require Tyyppi.T
  Tyyppi.T.apply(MyModule.callback(), MyModule.on_info/1, foo: 2)
  #⇒ {:ok,[foo_squared: 4]}
  Tyyppi.T.apply(MyModule.callback(), MyModule.on_info/1, foo: :ok)
  #⇒ {:error, {:args, :ok}}
  Tyyppi.T.apply(MyModule.callback(), MyModule.on_info/1, [])
  #⇒ {:error, {:arity, 0}}
  ```
  """
  defmacro apply(type, fun, args) do
    quote do
      %T{module: module, definition: definition} = T.parse(unquote(type))
      Function.apply(module, definition, unquote(fun), unquote(args))
    end
  end

  @doc """
  Applies the function from the current module, validating input arguments and output.

  See `apply/3` for details.
  """
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
    do: {:type, 0, fun, normalize_params(params)}

  def parse_definition(atom) when is_atom(atom), do: {:atom, 0, atom}

  def parse_definition(list) when is_list(list),
    do: {:type, 0, :union, Enum.map(list, &parse_definition/1)}

  def parse_definition(tuple) when is_tuple(tuple),
    do: {:type, 0, :tuple, tuple |> Tuple.to_list() |> Enum.map(&parse_definition/1)}

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
  def param_names(params),
    do: params |> T.normalize_params() |> Enum.map(&elem(&1, 0))

  defimpl String.Chars do
    @moduledoc false
    use Boundary, classify_to: Tyyppi.T

    def to_string(%T{module: nil, name: nil, definition: {:type, _, type, params}}) do
      args = Macro.generate_arguments(length(params || []), nil)
      ~s|#{type}(#{Enum.join(args, ", ")})|
    end

    def to_string(%T{module: module, name: name, params: params}) do
      args = Macro.generate_arguments(length(params || []), module)
      ~s|#{inspect(module)}.#{name}(#{Enum.join(args, ", ")})|
    end
  end
end
