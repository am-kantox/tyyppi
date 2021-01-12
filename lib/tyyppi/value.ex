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

  @typedoc "Type of the coercion function allowed"
  @type coercer :: (value() -> either())

  @typedoc "Type of the validation function allowed"
  @type validator :: (value() -> either()) | (value(), %{required(atom()) => any()} -> either())

  @type t :: %{
          __struct__: Tyyppi.Value,
          value: value(),
          documentation: String.t(),
          type: Tyyppi.T.t(),
          coercion: coercer(),
          validation: validator(),
          __meta__: %{subsection: String.t(), defined?: boolean(), errors: [any()]},
          __context__: %{required(atom()) => any()}
        }

  defstruct value: nil,
            type: Tyyppi.parse(any()),
            documentation: "",
            coercion: &Tyyppi.void_coercion/1,
            validation: &Tyyppi.void_validation/1,
            __meta__: %{subsection: "", defined?: false, errors: []},
            __context__: %{}

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
    # TODO cache it?

    case fun.(value) do
      :pop ->
        pop(data, :value)

      {get_value, update_value} ->
        update_value =
          with {:coercion, {:ok, cast}} <- {:coercion, data.coercion.(update_value)},
               true <- Tyyppi.of_type?(data.type, cast),
               {:validation, {:ok, update_value}} <- {:validation, validation(data).(cast)} do
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
  @doc false
  @spec validation(data :: t()) :: (value() -> either())
  def validation(%__MODULE__{validation: f}) when is_function(f, 1), do: &f.(&1)

  def validation(%__MODULE__{__context__: context, validation: f}) when is_function(f, 2),
    do: &f.(&1, context)

  def validation(%__MODULE__{}), do: &{:ok, &1}

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

  @typep factory_option :: {:value, any()} | {:documentation, String.t()}

  @spec any() :: t()
  @doc "Creates a not defined `any()` wrapped by `Tyyppi.Value`"
  def any, do: %Tyyppi.Value{type: Tyyppi.parse(any()), coercion: &Tyyppi.void_coercion/1}

  @spec any(any() | [factory_option()]) :: t()
  @doc "Factory for `any()` wrapped by `Tyyppi.Value`"
  def any([{:value, _} | _] = options), do: put_options(any(), options)
  def any([{:documentation, _} | _] = options), do: put_options(any(), options)
  def any(any), do: any(value: any)

  @spec atom() :: t()
  @doc "Creates a not defined `atom()` wrapped by `Tyyppi.Value`"
  def atom, do: %Tyyppi.Value{type: Tyyppi.parse(atom()), coercion: &Coercions.atom/1}

  @spec atom(options :: any() | [factory_option()]) :: t()
  @doc "Factory for `atom()` wrapped by `Tyyppi.Value`"
  def atom([{:value, _} | _] = options), do: put_options(atom(), options)
  def atom([{:documentation, _} | _] = options), do: put_options(atom(), options)
  def atom(atom), do: atom(value: atom)

  @spec string() :: t()
  @doc "Creates a not defined `String.t()` wrapped by `Tyyppi.Value`"
  def string, do: %Tyyppi.Value{type: Tyyppi.parse(String.t()), coercion: &Coercions.string/1}

  @spec string(options :: any() | [factory_option()]) :: t()
  @doc "Factory for `String.t()` wrapped by `Tyyppi.Value`"
  def string([{:value, _} | _] = options), do: put_options(string(), options)
  def string([{:documentation, _} | _] = options), do: put_options(string(), options)
  def string(string), do: string(value: string)

  @spec boolean() :: t()
  @doc "Creates a not defined `boolean()` wrapped by `Tyyppi.Value`"
  def boolean, do: %Tyyppi.Value{type: Tyyppi.parse(boolean()), coercion: &Coercions.boolean/1}
  @spec boolean(options :: any() | [factory_option()]) :: t()
  @doc "Factory for `boolean()` wrapped by `Tyyppi.Value`"
  def boolean(options) when is_list(options), do: put_options(boolean(), options)
  def boolean(boolean), do: boolean(value: boolean)

  @spec integer() :: t()
  @doc "Creates a not defined `integer()` wrapped by `Tyyppi.Value`"
  def integer, do: %Tyyppi.Value{type: Tyyppi.parse(integer()), coercion: &Coercions.integer/1}
  @spec integer(options :: any() | [factory_option()]) :: t()
  @doc "Factory for `integer()` wrapped by `Tyyppi.Value`"
  def integer(options) when is_list(options), do: put_options(integer(), options)
  def integer(integer), do: integer(value: integer)

  @spec non_neg_integer() :: t()
  @doc "Creates a not defined `non_neg_integer()` wrapped by `Tyyppi.Value`"
  def non_neg_integer,
    do: %Tyyppi.Value{
      type: Tyyppi.parse(non_neg_integer()),
      coercion: &Coercions.integer/1,
      validation: &Validations.non_neg_integer/1
    }

  @spec non_neg_integer(options :: any() | [factory_option()]) :: t()
  @doc "Factory for `non_neg_integer()` wrapped by `Tyyppi.Value`"
  def non_neg_integer(options) when is_list(options), do: put_options(non_neg_integer(), options)
  def non_neg_integer(non_neg_integer), do: non_neg_integer(value: non_neg_integer)

  @spec pos_integer() :: t()
  @doc "Creates a not defined `pos_integer()` wrapped by `Tyyppi.Value`"
  def pos_integer,
    do: %Tyyppi.Value{
      type: Tyyppi.parse(pos_integer()),
      coercion: &Coercions.integer/1,
      validation: &Validations.pos_integer/1
    }

  @spec pos_integer(options :: any() | [factory_option()]) :: t()
  @doc "Factory for `pos_integer()` wrapped by `Tyyppi.Value`"
  def pos_integer(options) when is_list(options), do: put_options(pos_integer(), options)
  def pos_integer(pos_integer), do: pos_integer(value: pos_integer)

  @spec timeout() :: t()
  @doc "Creates a not defined `timeout()` wrapped by `Tyyppi.Value`"
  def timeout,
    do: %Tyyppi.Value{
      type: Tyyppi.parse(timeout()),
      coercion: &Coercions.timeout/1,
      validation: &Validations.timeout/1
    }

  @spec timeout(options :: any() | [factory_option()]) :: t()
  @doc "Factory for `timeout()` wrapped by `Tyyppi.Value`"
  def timeout(options) when is_list(options), do: put_options(timeout(), options)
  def timeout(timeout), do: timeout(value: timeout)

  @spec pid() :: t()
  @doc "Creates a not defined `pid()` wrapped by `Tyyppi.Value`"
  def pid, do: %Tyyppi.Value{type: Tyyppi.parse(pid()), coercion: &Coercions.pid/1}

  @spec pid(options :: any() | [factory_option()]) :: t()
  @doc "Factory for `pid()` wrapped by `Tyyppi.Value`"
  def pid([{:value, _} | _] = options), do: put_options(pid(), options)
  def pid([{:documentation, _} | _] = options), do: put_options(pid(), options)
  def pid(pid), do: pid(value: pid)

  @spec pid(p1 :: non_neg_integer(), p2 :: non_neg_integer(), p3 :: non_neg_integer()) :: t()
  @doc "Factory for `pid()` wrapped by `Tyyppi.Value`"
  def pid(p1, p2, p3)
      when is_integer(p1) and p1 >= 0 and is_integer(p2) and p2 >= 0 and is_integer(p3) and
             p3 >= 0,
      do: pid(value: Enum.join([p1, p2, p3], "."))

  @spec mfa() :: t()
  @doc "Creates a not defined `mfa` wrapped by `Tyyppi.Value`"
  def mfa,
    do: %Tyyppi.Value{
      type: Tyyppi.parse({module(), atom(), non_neg_integer()}),
      validation: &Validations.mfa/1
    }

  @spec mfa(options :: {module(), atom(), non_neg_integer()} | [factory_option()]) :: t()
  @doc "Factory for `mfa` wrapped by `Tyyppi.Value`"
  def mfa(options) when is_list(options), do: put_options(mfa(), options)
  def mfa(mfa), do: mfa(value: mfa)

  @spec mfa(m :: module(), f :: atom(), a :: non_neg_integer()) :: t()
  @doc "Factory for `mfa` wrapped by `Tyyppi.Value`"
  def mfa(m, f, a) when is_atom(m) and is_atom(f) and is_integer(a) and a >= 0,
    do: mfa(value: {m, f, a})

  @spec mod_arg() :: t()
  @doc "Creates a not defined `mod_arg` wrapped by `Tyyppi.Value`"
  def mod_arg,
    do: %Tyyppi.Value{
      type: Tyyppi.parse({module(), list()}),
      validation: &Validations.mod_arg/1
    }

  @spec mod_arg(options :: {module(), list()} | [factory_option()]) :: t()
  @doc "Factory for `mod_arg` wrapped by `Tyyppi.Value`"
  def mod_arg(options) when is_list(options), do: put_options(mod_arg(), options)
  def mod_arg(mod_arg), do: mod_arg(value: mod_arg)

  @spec mod_arg(m :: module(), args :: list()) :: t()
  @doc "Factory for `mod_arg` wrapped by `Tyyppi.Value`"
  def mod_arg(m, args) when is_atom(m) and is_list(args), do: mod_arg(value: {m, args})

  #############################################################################

  @spec fun(:any | arity() | keyword() | fun()) :: t() | no_return
  @doc "Creates a not defined `fun` wrapped by `Tyyppi.Value`"
  def fun(arity \\ :any)

  def fun(:any),
    do: %Tyyppi.Value{
      type: Tyyppi.parse(fun()),
      validation: &Validations.fun/2
    }

  def fun(arity) when is_integer(arity) and arity >= 0 and arity <= 255,
    do: %Tyyppi.Value{fun(:any) | __context__: %{arity: arity}}

  def fun(options) when is_list(options),
    do:
      options
      |> Keyword.get(:value, :any)
      |> Function.info(:arity)
      |> elem(1)
      |> fun()
      |> put_options(options)

  def fun(f) when is_function(f), do: fun(value: f)

  #############################################################################

  @spec put_options(acc :: t(), options :: [factory_option()]) :: t()
  defp put_options(acc, options),
    do: Enum.reduce(options, acc, fn {k, v}, acc -> put_in(acc, [k], v) end)

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
