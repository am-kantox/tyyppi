defmodule Tyyppi.Value do
  @moduledoc """
  Value type to be used with `Tyyppi`.

  It wraps the standard _Elixir_ type in a struct, also providing optional coercion,
    validation, and `Access` implementation.
  """

  use Tyyppi

  @typedoc "Type of the value behind this struct"
  @type value :: any()
  @type either :: {:ok, value()} | {:error, any()}

  @type t :: %{
          __struct__: Tyyppi.Value,
          value: value(),
          type: Tyyppi.T.t(),
          coercion: (value() -> either()),
          validation: (value() -> either()),
          __meta__: %{defined?: boolean, errors: [any()]}
        }

  defstruct value: nil,
            type: Tyyppi.parse(any()),
            coercion: &Tyyppi.void_coercion/1,
            validation: &Tyyppi.void_validation/1,
            __meta__: %{defined?: false, errors: []}

  @behaviour Access

  defmacrop defined,
    do: quote(do: %__MODULE__{__meta__: %{defined?: true}, value: var!(value)})

  defmacrop errors,
    do: quote(do: %__MODULE__{__meta__: %{defined?: false, errors: var!(errors)}})

  defmacrop meta,
    do: quote(do: %__MODULE__{__meta__: var!(meta), value: var!(value)})

  @impl Access
  def fetch(defined(), :value), do: {:ok, value}
  def fetch(%__MODULE__{}, :value), do: :error
  def fetch(errors(), :errors), do: {:ok, errors}
  def fetch(%__MODULE__{}, :errors), do: :error

  @impl Access
  def pop(meta() = data, :value),
    do: {value, %__MODULE__{data | __meta__: Map.put(meta, :defined?, false), value: nil}}

  def pop(%__MODULE__{}, key),
    do: raise(BadStructError, struct: __MODULE__, term: key)

  @impl Access
  def get_and_update(meta() = data, :value, fun) do
    case fun.(value) do
      :pop ->
        pop(data, :value)

      {get_value, update_value} ->
        update_value =
          with {:coercion, {:ok, cast}} <- {:coercion, data.coercion.(update_value)},
               true <- Tyyppi.of_type?(data.type, cast),
               {:validation, {:ok, update_value}} <- {:validation, data.validation.(cast)} do
            %__MODULE__{data | __meta__: Map.put(meta, :defined?, true), value: update_value}
          else
            false ->
              errors = [type: [expected: to_string(data.type), got: update_value]]
              %__MODULE__{data | __meta__: %{meta | defined?: false, errors: errors}}

            {operation, {:error, error}} ->
              errors = [{operation, [message: error, got: update_value]}]
              %__MODULE__{data | __meta__: %{meta | defined?: false, errors: errors}}
          end

        {get_value, update_value}
    end
  end

  def get_and_update(%__MODULE__{}, key, _),
    do: raise(BadStructError, struct: __MODULE__, term: key)

  #############################################################################

  @spec value_type?(Tyyppi.T.t()) :: boolean()
  @doc false
  def value_type?(%Tyyppi.T{quoted: quoted} = _type),
    do: Tyyppi.parse(Tyyppi.Value.t()).quoted == quoted

  @spec value?(any()) :: boolean()
  @doc false
  def value?(%Tyyppi.Value{}), do: true
  def value?(_), do: false

  #############################################################################

  defmodule Coercions do
    @moduledoc false

    @spec atom(value :: any()) :: Tyyppi.Value.either()
    def atom(atom) when is_atom(atom), do: {:ok, atom}
    def atom(binary) when is_binary(binary), do: {:ok, String.to_atom(binary)}
    def atom(charlist) when is_list(charlist), do: {:ok, :erlang.list_to_atom(charlist)}

    def atom(_not_atom),
      do: {:error, "Expected atom(), charlist() or binary()"}

    @spec integer(value :: any()) :: Tyyppi.Value.either()
    def integer(i) when is_integer(i), do: {:ok, i}
    def integer(n) when is_number(n), do: {:ok, round(n)}

    def integer(binary) when is_binary(binary) do
      case Integer.parse(binary) do
        {i, ""} -> {:ok, i}
        {i, tail} -> {:error, ~s|Trailing symbols while parsing integer [#{i}]: "#{tail}"|}
        :error -> {:error, ~s|Error parsing integer: "#{binary}"|}
      end
    end

    def integer(_not_integer),
      do: {:error, "Expected number() or binary()"}
  end

  @spec atom(value :: any()) :: t()
  @doc "Factory for `atom()` wrapped by `Tyyppi.Value`"
  def atom(value) do
    put_in(
      %Tyyppi.Value{type: Tyyppi.parse(atom()), coercion: &Coercions.atom/1},
      [:value],
      value
    )
  end

  @spec integer(value :: any()) :: t()
  @doc "Factory for `integer()` wrapped by `Tyyppi.Value`"
  def integer(value) do
    put_in(
      %Tyyppi.Value{type: Tyyppi.parse(integer()), coercion: &Coercions.integer/1},
      [:value],
      value
    )
  end

  #############################################################################

  defimpl Inspect do
    @moduledoc false
    import Inspect.Algebra

    def inspect(%Tyyppi.Value{value: value, __meta__: %{defined?: true}}, opts) do
      concat(["‹", to_doc(value, opts), "›"])
    end

    def inspect(%Tyyppi.Value{value: value}, opts) do
      concat(["‹✗", to_doc(value, opts), "›"])
    end
  end
end
