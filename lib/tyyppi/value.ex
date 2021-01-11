defmodule Tyyppi.Value do
  @moduledoc """
  Value type to be used with `Tyyppi`.

  It wraps the standard _Elixir_ type in a struct, also providing optional coercion,
    validation, documentation, and `Access` implementation.
  """

  require Tyyppi
  require Tyyppi.T

  alias Tyyppi.Value.{Coercions, Validations}

  @typedoc "Type of the value behind this struct"
  @type value :: any()

  @typedoc "Type returned from coercions and validations, typical pair of ok/error tuples"
  @type either :: {:ok, value()} | {:error, any()}

  @type t :: %{
          __struct__: Tyyppi.Value,
          value: value(),
          documentation: String.t(),
          type: Tyyppi.T.t(),
          coercion: (value() -> either()),
          validation: (value() -> either()),
          __meta__: %{subsection: String.t(), defined?: boolean(), errors: [any()]}
        }

  defstruct value: nil,
            type: Tyyppi.parse(any()),
            documentation: "",
            coercion: &Tyyppi.void_coercion/1,
            validation: &Tyyppi.void_validation/1,
            __meta__: %{subsection: "", defined?: false, errors: []}

  defmacrop defined,
    do: quote(do: %__MODULE__{__meta__: %{defined?: true}, value: var!(value)})

  defmacrop meta,
    do: quote(do: %__MODULE__{__meta__: var!(meta)})

  defmacrop value,
    do: quote(do: %__MODULE__{__meta__: var!(meta), value: var!(value)})

  @behaviour Access

  @impl Access
  @doc false
  def fetch(defined(), :value), do: {:ok, value}
  def fetch(%__MODULE__{}, :value), do: :error
  def fetch(meta(), :errors) when meta.errors == [], do: :error
  def fetch(meta(), :errors), do: {:ok, meta.errors}

  def fetch(%__MODULE__{documentation: <<_::8, _::binary()>> = documentation}, :documentation),
    do: {:ok, documentation}

  def fetch(%__MODULE__{}, :documentation), do: :error

  @impl Access
  @doc false
  def pop(value() = data, :value) do
    {value, %__MODULE__{data | __meta__: Map.put(meta, :defined?, false), value: nil}}
  end

  def pop(meta() = data, :errors) do
    {with([] <- meta.errors, do: nil), %__MODULE__{data | __meta__: Map.put(meta, :errors, [])}}
  end

  def pop(%__MODULE__{documentation: documentation} = data, :documentation),
    do: {documentation, %__MODULE__{data | documentation: ""}}

  def pop(%__MODULE__{}, key),
    do: raise(BadStructError, struct: __MODULE__, term: key)

  @impl Access
  @doc false
  def get_and_update(value() = data, :value, fun) do
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

  @doc "Helper guard to match Value instances"
  defguard is_value(value) when is_map(value) and value.__struct__ == Tyyppi.Value

  @spec value?(any()) :: boolean()
  @doc false
  def value?(%Tyyppi.Value{}), do: true
  def value?(_), do: false

  @spec valid?(t()) :: boolean()
  @doc false
  def valid?(meta()) when meta.defined? == true, do: true
  def valid?(_), do: false
  #############################################################################

  @spec any() :: t()
  @doc "Creates a not defined `any()` wrapped by `Tyyppi.Value`"
  def any, do: %Tyyppi.Value{type: Tyyppi.parse(any()), coercion: &Tyyppi.void_coercion/1}

  @spec any(value :: any()) :: t()
  @doc "Factory for `any()` wrapped by `Tyyppi.Value`"
  def any(value), do: put_in(any(), [:value], value)

  @spec atom() :: t()
  @doc "AFactory for `atom()` wrapped by `Tyyppi.Value`"
  def atom, do: %Tyyppi.Value{type: Tyyppi.parse(atom()), coercion: &Coercions.atom/1}
  @spec atom(value :: any()) :: t()
  @doc "Factory for `atom()` wrapped by `Tyyppi.Value`"
  def atom(value), do: put_in(atom(), [:value], value)

  @spec string() :: t()
  @doc "AFactory for `String.t()` wrapped by `Tyyppi.Value`"
  def string, do: %Tyyppi.Value{type: Tyyppi.parse(String.t()), coercion: &Coercions.string/1}
  @spec string(value :: String.t()) :: t()
  @doc "Factory for `String.t()` wrapped by `Tyyppi.Value`"
  def string(value), do: put_in(string(), [:value], value)

  @spec boolean() :: t()
  @doc "AFactory for `boolean()` wrapped by `Tyyppi.Value`"
  def boolean, do: %Tyyppi.Value{type: Tyyppi.parse(boolean()), coercion: &Coercions.boolean/1}
  @spec boolean(value :: boolean()) :: t()
  @doc "Factory for `boolean()` wrapped by `Tyyppi.Value`"
  def boolean(value), do: put_in(boolean(), [:value], value)

  @spec integer() :: t()
  @doc "AFactory for `integer()` wrapped by `Tyyppi.Value`"
  def integer, do: %Tyyppi.Value{type: Tyyppi.parse(integer()), coercion: &Coercions.integer/1}
  @spec integer(value :: any()) :: t()
  @doc "Factory for `integer()` wrapped by `Tyyppi.Value`"
  def integer(value), do: put_in(integer(), [:value], value)

  @spec non_neg_integer() :: t()
  @doc "AFactory for `non_neg_integer()` wrapped by `Tyyppi.Value`"
  def non_neg_integer,
    do: %Tyyppi.Value{
      type: Tyyppi.parse(non_neg_integer()),
      coercion: &Coercions.integer/1,
      validation: &Validations.non_neg_integer/1
    }

  @spec non_neg_integer(value :: any()) :: t()
  @doc "Factory for `non_neg_integer()` wrapped by `Tyyppi.Value`"
  def non_neg_integer(value), do: put_in(non_neg_integer(), [:value], value)

  @spec pos_integer() :: t()
  @doc "AFactory for `pos_integer()` wrapped by `Tyyppi.Value`"
  def pos_integer,
    do: %Tyyppi.Value{
      type: Tyyppi.parse(pos_integer()),
      coercion: &Coercions.integer/1,
      validation: &Validations.pos_integer/1
    }

  @spec pos_integer(value :: any()) :: t()
  @doc "Factory for `pos_integer()` wrapped by `Tyyppi.Value`"
  def pos_integer(value), do: put_in(pos_integer(), [:value], value)

  @spec timeout() :: t()
  @doc "AFactory for `timeout()` wrapped by `Tyyppi.Value`"
  def timeout,
    do: %Tyyppi.Value{
      type: Tyyppi.parse(timeout()),
      coercion: &Coercions.timeout/1,
      validation: &Validations.timeout/1
    }

  @spec timeout(value :: any()) :: t()
  @doc "Factory for `timeout()` wrapped by `Tyyppi.Value`"
  def timeout(value), do: put_in(timeout(), [:value], value)

  @spec pid() :: t()
  @doc "AFactory for `pid()` wrapped by `Tyyppi.Value`"
  def pid, do: %Tyyppi.Value{type: Tyyppi.parse(pid()), coercion: &Coercions.pid/1}
  @spec pid(value :: any()) :: t()
  @doc "Factory for `pid()` wrapped by `Tyyppi.Value`"
  def pid(value), do: put_in(pid(), [:value], value)
  @spec pid(p1 :: non_neg_integer(), p2 :: non_neg_integer(), p3 :: non_neg_integer()) :: t()
  @doc "Factory for `pid()` wrapped by `Tyyppi.Value`"
  def pid(p1, p2, p3)
      when is_integer(p1) and p1 >= 0 and is_integer(p2) and p2 >= 0 and is_integer(p3) and
             p3 >= 0,
      do: [p1, p2, p3] |> Enum.join(".") |> pid()

  @spec mfa() :: t()
  @doc "AFactory for `mfa` wrapped by `Tyyppi.Value`"
  def mfa,
    do: %Tyyppi.Value{
      type: Tyyppi.parse({module(), atom(), non_neg_integer()}),
      validation: &Validations.mfa/1
    }

  @spec mfa({m :: module(), f :: atom(), a :: non_neg_integer()}) :: t()
  @doc "Factory for `mfa` wrapped by `Tyyppi.Value`"
  def mfa(mfa), do: put_in(mfa(), [:value], mfa)

  @spec mfa(m :: module(), f :: atom(), a :: non_neg_integer()) :: t()
  @doc "Factory for `mfa` wrapped by `Tyyppi.Value`"
  def mfa(m, f, a) when is_atom(m) and is_atom(f) and is_integer(a) and a >= 0, do: mfa({m, f, a})

  @spec mod_arg() :: t()
  @doc "AFactory for `mod_arg` wrapped by `Tyyppi.Value`"
  def mod_arg,
    do: %Tyyppi.Value{
      type: Tyyppi.parse({module(), list()}),
      validation: &Validations.mod_arg/1
    }

  @spec mod_arg({m :: module(), args :: list()}) :: t()
  @doc "Factory for `mod_arg` wrapped by `Tyyppi.Value`"
  def mod_arg(mod_arg), do: put_in(mod_arg(), [:value], mod_arg)

  @spec mod_arg(m :: module(), args :: list()) :: t()
  @doc "Factory for `mod_arg` wrapped by `Tyyppi.Value`"
  def mod_arg(m, args) when is_atom(m) and is_list(args), do: mod_arg({m, args})

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
