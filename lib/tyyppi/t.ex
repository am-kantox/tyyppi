defmodule Tyyppi.T do
  @moduledoc """
  Raw type wrapper.
  """
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
          | :t
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
          | :T
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

  defmacro parse({{:., _, [module, fun]}, _, params}) do
    quote bind_quoted: [module: module, fun: fun, params: params] do
      Tyyppi.Stats.type({module, fun, length(params)})
    end
  end

  defmacro parse({{:., _, [{:__aliases__, _, aliases}, fun]}, _, params}) do
    quote bind_quoted: [aliases: aliases, fun: fun, params: params] do
      Tyyppi.Stats.type({Module.concat(aliases), fun, length(params)})
    end
  end

  defmacro of?(type, term) do
    quote do
      %Tyyppi.T{module: module, definition: definition} = Tyyppi.T.parse(unquote(type))
      Tyyppi.T.Matchers.of?(module, definition, unquote(term))
    end
  end

  @type test1 :: GenServer.on_start()
  @type test2 :: %{
          :foo => :ok | {:error, term},
          :on_start => test1()
        }
  @type test3 :: %{required(atom()) => integer()}
  @type test4 :: %{optional(atom()) => float()}
  @type test5 :: list()
  @type test6 :: list(pos_integer())
  @type test7 :: [neg_integer()]
  @type test8 :: nonempty_list(number())
  @type test9 :: maybe_improper_list(number(), pid())
  @type test10 :: nonempty_improper_list(number(), pid())
  @type test11 :: nonempty_maybe_improper_list(number(), pid())
end
