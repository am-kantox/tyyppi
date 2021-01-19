defmodule Tyyppi do
  @moduledoc """
  The main interface to `Tyyppi` library. Usually, functions and macros
  presented is this module are enough to work with `Tyyppi`.


  """

  use Boundary, exports: [Function, Matchers, Stats]

  require Logger

  alias Tyyppi.{Matchers, Stats, T}
  import Tyyppi.T, only: [normalize_params: 1, param_names: 1, parse_definition: 1]

  @doc false
  defguard is_params(params) when is_list(params) or is_atom(params)

  @doc """
  Sigil to simplify specification of `Tyyppi.T.t()` type, it’s literally the wrapper for `Tyyppi.parse/1`.

  ## Examples
      iex> import Tyyppi
      iex> ~t[integer()]
      %Tyyppi.T{
        definition: {:type, 0, :integer, []},
        module: nil,
        name: nil,
        params: [],
        quoted: {:integer, [], []},
        source: nil,
        type: :built_in
      }
      ...> ~t[atom]
      %Tyyppi.T{
        definition: {:type, 0, :atom, []},
        module: nil,
        name: nil,
        params: [],
        quoted: {:atom, [], []},
        source: nil,
        type: :built_in
      }
  """
  defmacro sigil_t({:<<>>, _meta, [string]}, []) when is_binary(string) do
    quote bind_quoted: [string: string] do
      string
      |> :elixir_interpolation.unescape_chars()
      |> Code.string_to_quoted!()
      |> Tyyppi.parse_quoted()
    end
  end

  defmacro sigil_t({:<<>>, meta, pieces}, []) do
    tokens =
      case :elixir_interpolation.unescape_tokens(pieces) do
        {:ok, unescaped_tokens} -> unescaped_tokens
        {:error, reason} -> raise ArgumentError, to_string(reason)
      end

    quote do
      unquote({:<<>>, meta, tokens})
      |> Code.string_to_quoted!()
      |> Tyyppi.parse_quoted()
    end
  end

  @doc """
  Parses the type as by spec and returns its `Tyyppi.T` representation.

  _Example:_

      iex> require Tyyppi
      ...> Tyyppi.parse(GenServer.on_start()) |> Map.put(:source, nil)
      %Tyyppi.T{
        definition: {:type, 704, :union,
        [
          {:type, 0, :tuple, [{:atom, 0, :ok}, {:type, 704, :pid, []}]},
          {:atom, 0, :ignore},
          {:type, 0, :tuple,
            [
              {:atom, 0, :error},
              {:type, 704, :union,
              [
                {:type, 0, :tuple,
                  [{:atom, 0, :already_started}, {:type, 704, :pid, []}]},
                {:type, 704, :term, []}
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

  defmacro parse({fun, _, params}) when is_atom(fun) and fun != :{} and is_params(params) do
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

  @doc """
  Returns `true` if the `term` passed as the second parameter is of type `type`.
    The first parameter is expected to be a `type` as in specs, e. g. `atom()` or
    `GenServer.on_start()`.

  _Examples:_

      iex> require Tyyppi
      ...> Tyyppi.of?(atom(), :ok)
      true
      ...> Tyyppi.of?(atom(), 42)
      false
      ...> Tyyppi.of?(GenServer.on_start(), {:error, {:already_started, self()}})
      true
      ...> Tyyppi.of?(GenServer.on_start(), :foo)
      false
  """
  defmacro of?(type, term) do
    quote do
      %Tyyppi.T{module: module, definition: definition} = Tyyppi.parse(unquote(type))
      Matchers.of?(module, definition, unquote(term))
    end
  end

  @spec of_type?(Tyyppi.T.t(), any()) :: boolean()
  @doc """
  Returns `true` if the `term` passed as the second parameter is of type `type`.
    The first parameter is expected to be of type `Tyyppi.T.t()`.

  _Examples:_

      iex> require Tyyppi
      ...> type = Tyyppi.parse(atom())
      %Tyyppi.T{
        definition: {:type, 0, :atom, []},
        module: nil,
        name: nil,
        params: [],
        quoted: {:atom, [], []},
        source: nil,
        type: :built_in
      }
      ...> Tyyppi.of_type?(type, :ok)
      true
      ...> Tyyppi.of_type?(type, 42)
      false
      ...> type = Tyyppi.parse(GenServer.on_start())
      ...> Tyyppi.of_type?(type, {:error, {:already_started, self()}})
      true
      ...> Tyyppi.of_type?(type, :foo)
      false
  """
  def of_type?(%T{module: module, definition: definition}, term),
    do: Matchers.of?(module, definition, term)

  @doc """
  **Experimental:** applies the **local** function given as an argument
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
  require Tyyppi

  Tyyppi.apply(MyModule.callback(), &MyModule.on_info/1, 2)
  #⇒ {:ok, [foo_squared: 4]}
  Tyyppi.apply(MyModule.callback(), &MyModule.on_info/1, :ok)
  #⇒ {:error, {:args, :ok}}
  Tyyppi.apply(MyModule.callback(), &MyModule.on_info/1, [])
  #⇒ {:error, {:arity, 0}}
  ```
  """
  defmacro apply(type, fun, args) do
    quote do
      %Tyyppi.T{module: module, definition: definition} = Tyyppi.parse(unquote(type))
      Tyyppi.Function.apply(module, definition, unquote(fun), unquote(args))
    end
  end

  @doc """
  **Experimental:** applies the **external** function given as an argument
    in the form `&Module.fun/arity` or **anonymous** function with arguments.
    Validates the arguments given and the result produced by the call.

    _Examples:_

        iex> require Tyyppi
        ...> Tyyppi.apply((atom() -> binary()),
        ...>    fn a -> to_string(a) end, [:foo])
        {:ok, "foo"}
        ...> result = Tyyppi.apply((atom() -> binary()),
        ...>    fn -> "foo" end, [:foo])
        ...> match?({:error, {:fun, _}}, result)
        true
        ...> Tyyppi.apply((atom() -> binary()),
        ...>    fn _ -> 42 end, ["foo"])
        {:error, {:args, ["foo"]}}
        ...> Tyyppi.apply((atom() -> binary()),
        ...>    fn _ -> 42 end, [:foo])
        {:error, {:result, 42}}
  """
  defmacro apply(fun, args) do
    quote do
      with %{module: module, name: fun, arity: arity} <-
             Map.new(Elixir.Function.info(unquote(fun))),
           {:ok, specs} <- Code.Typespec.fetch_specs(module),
           {{fun, arity}, [spec]} <- Enum.find(specs, &match?({{^fun, ^arity}, _}, &1)),
           do: Tyyppi.Function.apply(module, spec, unquote(fun), unquote(args)),
           else: (result -> {:error, {:no_spec, result}})
    end
  end

  @doc false
  defdelegate parse_quoted(type), to: Tyyppi.T

  @doc false
  defdelegate void_validation(value), to: Tyyppi.Value.Validations, as: :void

  @doc false
  defdelegate void_coercion(value), to: Tyyppi.Value.Coercions, as: :void

  @doc false
  defmacro coproduct(types), do: {:|, [], types}

  @doc false
  def setup_ast(import?) do
    [
      if(import?,
        do: quote(do: import(Tyyppi)),
        else: quote(do: require(Tyyppi))
      ),
      quote do
        alias Tyyppi.Value

        import Kernel, except: [defstruct: 1]
        import Tyyppi.Struct, only: [defstruct: 1]

        :ok
      end
    ]
  end

  @doc false
  defmacro __using__(opts \\ []) do
    start? =
      if Keyword.get(opts, :start, false), do: quote(do: Tyyppi.Stats.start_link()), else: []

    import? = Keyword.get(opts, :import, false)

    [setup_ast(import?), start?]
  end
end
