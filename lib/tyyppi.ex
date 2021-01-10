defmodule Tyyppi do
  @moduledoc """
  The main interface to `Tyyppi` library. Usually, functions and macros
  presented is this module are enough to work with `Tyyppi`.


  """

  use Boundary, exports: [Function, Matchers, Stats, T]

  alias Tyyppi.{Matchers, T}

  @doc false
  defmacro __using__(_opts) do
    quote do
      require Tyyppi
      require Tyyppi.T
    end
  end

  @doc """
  Parses the type as by spec and returns its `Tyyppi.T` representation.
  See `Tyyppi.T.parse/1` for details.
  """
  defmacro parse(ast), do: quote(do: T.parse(unquote(ast)))

  @doc """
  Returns `true` if the `term` passed as the second parameter is of type `type`.
    The first parameter is expected to be a `type` as in specs, e. g. `atom()` or
    `GenServer.on_start()`. See `Tyyppi.T.of?/2` for details.
  """
  defmacro of?(type, term), do: quote(do: T.of?(unquote(type), unquote(term)))

  @spec of_type?(Tyyppi.T.t(), any()) :: boolean()
  @doc """
  Returns `true` if the `term` passed as the second parameter is of type `type`.
    The first parameter is expected to be of type `Tyyppi.T.t()`.

  _Examples:_

      iex> use Tyyppi
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
  **Experimental:** applies the **local** function given as an argument.
    Validates the arguments given and the result produced by the call.

    See `apply/3` for details.
  """
  defmacro apply(fun, args), do: quote(do: T.apply(unquote(fun), unquote(args)))

  @doc """
  **Experimental:** applies the **external** function given as an argument
    in the form `&Module.fun/arity` or **anonymous** function with arguments.
    Validates the arguments given and the result produced by the call.

    _Examples:_

        iex> use Tyyppi
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
  defmacro apply(type, fun, args),
    do: quote(do: T.apply(unquote(type), unquote(fun), unquote(args)))

  @doc false
  defdelegate void_validation(value), to: Tyyppi.Value.Validations, as: :void

  @doc false
  defdelegate void_coercion(value), to: Tyyppi.Value.Coercions, as: :void
end
