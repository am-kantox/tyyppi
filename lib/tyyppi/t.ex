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

  @type test_atom_1 :: atom()
  @type test_atom_2 :: true
  @type test_atom_3 :: false | nil

  @type test_remote :: GenServer.on_start()

  @type test_map_1 :: %{
          :foo => :ok | {:error, term},
          :on_start => test_remote()
        }
  @type test_map_2 :: %{required(atom()) => integer()}
  @type test_map_3 :: %{optional(atom()) => float()}

  @type test_list_1 :: []
  @type test_list_2 :: list()
  @type test_list_3 :: list(pos_integer())
  @type test_list_4 :: [neg_integer()]
  @type test_list_5 :: nonempty_list(number())
  @type test_list_6 :: maybe_improper_list(number(), pid())
  @type test_list_7 :: nonempty_improper_list(number(), pid())
  @type test_list_8 :: nonempty_maybe_improper_list(number(), pid())

  @type test_binary_1 :: <<>>
  @type test_binary_2 :: <<_::5>>
  @type test_binary_3 :: <<_::_*3>>
  @type test_binary_4 :: <<_::1, _::_*3>>
end
