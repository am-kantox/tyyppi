defmodule Tyyppi.Stats do
  @moduledoc """
  Process caching the loaded types information.

  Whether your application often uses the types information, it makes sense
    to cache it in a process state, because gathering it takes some time. In such
    a case your application should start this process in the application’s
    supervision tree, and call `#{inspect(__MODULE__)}.rehash!/0` every time when the
    new module is compiled in the runtime.
  """

  alias Tyyppi.T

  use GenServer

  @typedoc "Types information cache"
  @type info :: %{(... -> any()) => Tyyppi.T.t()}

  @typedoc """
  Function to be called upon rehashing. When arity is `0`, the full new state
    would be passed, for arity `1`, `added` and `removed` types would be passed,
    for arity `2`, `added`, `removed`, and full state would be passed.
  """
  @type callback ::
          (info() -> any()) | (info(), info() -> any()) | (info(), info(), info() -> any())

  @spec start_link(meta :: keyword()) :: GenServer.on_start()
  @doc """
  Starts the cache process. The optional parameter might contain any payload
    that will be stored in the process’ state.

  If a payload has `callback :: (-> :ok)` parameter, this function will
    be called every time the types information gets rehashed.
  """
  def start_link(meta \\ []),
    do: GenServer.start_link(__MODULE__, %{meta: meta, types: %{}}, name: __MODULE__)

  @spec types :: info()
  @doc """
  Retrieves all the types information currently available in the system.
  """
  def types, do: GenServer.call(__MODULE__, :types)

  @spec type(
          (... -> any())
          | atom()
          | T.ast()
          | T.raw()
          | {module(), atom(), list() | nil | non_neg_integer()}
        ) ::
          Tyyppi.T.t()
  @doc """
  Retrieves the type information for the type given.
  """

  def type({module, fun, arity}) when is_atom(module) and is_atom(fun) and is_integer(arity),
    do: module |> Function.capture(fun, arity) |> type()

  def type(fun) when is_function(fun), do: Map.get(types(), fun)

  def type(definition) when is_tuple(definition) do
    %T{
      type: :built_in,
      module: nil,
      name: nil,
      params: [],
      source: nil,
      definition: definition,
      quoted: definition_to_quoted(definition)
    }
  end

  @spec rehash! :: :ok
  @doc """
  Rehashes the types information currently available in the system. This function
    should be called after the application has created a module in runtime for this
    module information to appear in the cache.
  """
  def rehash!, do: GenServer.cast(__MODULE__, :rehash!)

  @impl GenServer
  @doc false
  def init(state), do: {:ok, state, {:continue, :load}}

  @impl GenServer
  @doc false
  def handle_continue(:load, state),
    do: {:noreply, %{state | types: loaded_types(state.types, state.meta[:callback])}}

  @impl GenServer
  @doc false
  def handle_cast(:rehash!, state),
    do: {:noreply, %{state | types: loaded_types(state.types, state.meta[:callback])}}

  @impl GenServer
  @doc false
  def handle_call(:types, _from, state), do: {:reply, state.types, state}

  @spec type_to_map(module(), charlist(), {atom(), Tyyppi.T.ast()}) ::
          {(... -> any()), Tyyppi.T.t()}
  defp type_to_map(module, source, {type, {name, definition, params}}) do
    param_names = T.param_names(params)

    {Function.capture(module, name, length(params)),
     %T{
       type: type,
       module: module,
       name: name,
       params: params,
       source: to_string(source),
       definition: definition,
       quoted: quote(do: unquote(module).unquote(name)(unquote_splicing(param_names)))
     }}
  end

  @spec loaded_types(types :: nil | info(), callback :: nil | callback()) :: info()
  defp loaded_types(_types, nil) do
    :code.all_loaded()
    |> Enum.flat_map(fn {module, source} ->
      case Code.Typespec.fetch_types(module) do
        {:ok, types} -> Enum.map(types, &type_to_map(module, source, &1))
        :error -> []
      end
    end)
    |> Map.new()
  end

  defp loaded_types(_types, callback) when is_function(callback, 1) do
    result = loaded_types(nil, nil)
    callback.(result)
    result
  end

  defp loaded_types(types, callback) when is_function(callback, 2) do
    result = loaded_types(nil, nil)
    added = Map.take(result, Map.keys(result) -- Map.keys(types))
    removed = Map.take(types, Map.keys(types) -- Map.keys(result))
    callback.(added, removed)
    result
  end

  defp loaded_types(types, callback) when is_function(callback, 3) do
    result = loaded_types(nil, nil)
    added = Map.take(result, Map.keys(result) -- Map.keys(types))
    removed = Map.take(types, Map.keys(types) -- Map.keys(result))
    callback.(added, removed, result)
    result
  end

  defp definition_to_quoted({:type, _, name, params}),
    do: quote(do: unquote(name)(unquote_splicing(params)))

  defp definition_to_quoted({:atom, _, name}),
    do: quote(do: unquote(name))
end
