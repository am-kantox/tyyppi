defmodule Tyyppi.T do
  @moduledoc """
  Raw type wrapper.
  """

  alias Tyyppi.{Stats, T, T.Function}

  @type kind :: :type | :remote_type | :user_type | :ann_type | :atom | :var
  @type visibility :: :typep | :type | :opaque
  @type simple ::
          :union
          | :term
          | :list
          | :map
          | :any
          | :pid
          | :record
          | :fun
          | :tuple
          | :des3_cbc
          | :non_neg_integer
          | :maybe_improper_list
          | :string
          | :nonempty_string
          | :af_lit_atom
          | nil
          | :filename_all
          | :integer
          | :relation
          | :pos_integer
          | :binary
          | :iter
          | :reference
          | :idn
          | :abstract_expr
          | :atom
          | :a_set
          | :byte
          | :iterator
          | :iovec
          | :a_function
          | :range
          | :filename
          | :deflated
          | :nonempty_list
          | :input
          | :boolean
          | :af_clause
          | :receive
          | :module
          | :orddict
          | :check_schedulers
          | :set
          | :af_atom
          | :af_variable
          | :queue
          | :tree

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

  defmacro parse(fun) when fun in [nil, true, false] do
    quote do
      %T{
        module: nil,
        name: unquote(fun),
        source: :preloaded,
        type: :type,
        params: [],
        definition: {:type, 0, unquote(fun), []}
      }
    end
  end

  defmacro parse({fun, _, params}) when is_atom(fun) and is_params(params) do
    params = if is_nil(params), do: [], else: params

    quote do
      %T{
        module: nil,
        name: unquote(fun),
        source: :preloaded,
        type: :type,
        params: unquote(params),
        definition: {:type, 0, unquote(fun), unquote(params)}
      }
    end
  end

  defmacro parse({{:., _, [module, fun]}, _, params}) when is_params(params) do
    params = if is_nil(params), do: [], else: params

    quote bind_quoted: [module: module, fun: fun, params: params] do
      Stats.type({module, fun, length(params)})
    end
  end

  defmacro parse({{:., _, [{:__aliases__, _, aliases}, fun]}, _, params})
           when is_params(params) do
    params = if is_nil(params), do: [], else: params

    quote bind_quoted: [aliases: aliases, fun: fun, params: params] do
      Stats.type({Module.concat(aliases), fun, length(params)})
    end
  end

  defmacro of?(type, term) do
    quote do
      %T{module: module, definition: definition} = T.parse(unquote(type))
      T.Matchers.of?(module, definition, unquote(term))
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
end
