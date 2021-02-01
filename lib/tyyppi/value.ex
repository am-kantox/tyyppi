defmodule Tyyppi.Value do
  @moduledoc """
  Value type to be used with `Tyyppi`.

  It wraps the standard _Elixir_ type in a struct, also providing optional coercion,
    validation, documentation, and `Access` implementation.

  ## Built-in constructors

  * `any` 
  * `atom` 
  * `string` 
  * `boolean` 
  * `integer` 
  * `non_neg_integer` 
  * `pos_integer` 
  * `timeout` 
  * `pid` 
  * `mfa` 
  * `mod_arg` 
  * `fun` 
  * `one_of` 
  * `formulae` 
  * `list` — creates a `[type()]` wrapped into a value
  * `struct` 
  """

  require Logger
  require Tyyppi

  alias Tyyppi.Value
  alias Tyyppi.Value.{Coercions, Encodings, Generations, Validations}

  @typedoc "Type of the value behind this struct"
  @type value :: any()

  @typedoc "Type returned from coercions and validations, typical pair of ok/error tuples"
  @type either :: {:ok, value()} | {:error, any()}

  @typedoc "Type of the coercion function allowed"
  @type coercer :: (value() -> either())

  @typedoc "Type of the encoder function, that might be used for e. g. Json serialization"
  @type encoder :: (value(), keyword() -> binary()) | nil

  @typedoc "Type of the generation function, basically returning a stream of generated values"
  if Code.ensure_loaded?(StreamData) do
    @type generation :: StreamData.t(value())
  else
    @type generation :: Enumerable.t()
  end

  @typedoc "Type of the generator function, producing the stream of `value()`"
  @type generator :: (() -> generation()) | (any() -> generation())

  @typedoc "Type of the validation function allowed"
  @type validator :: (value() -> either()) | (value(), %{required(atom()) => any()} -> either())

  @type t(wrapped) :: %{
          __struct__: Tyyppi.Value,
          value: value(),
          documentation: String.t(),
          type: Tyyppi.T.t(wrapped),
          coercion: coercer(),
          validation: validator(),
          encoding: encoder(),
          generation: {generator(), any()} | generator() | nil,
          __meta__: %{
            defined?: boolean(),
            optional?: boolean(),
            errors: [any()],
            subsection: String.t()
          },
          __context__: %{optional(atom()) => any()}
        }
  @type t() :: t(term())

  defstruct value: nil,
            type: Tyyppi.parse(any()),
            documentation: "",
            coercion: &Tyyppi.void_coercion/1,
            validation: &Tyyppi.void_validation/1,
            encoding: nil,
            generation: nil,
            __meta__: %{defined?: false, optional?: false, errors: [], subsection: ""},
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
    case fun.(value) do
      :pop ->
        pop(data, :value)

      {get_value, update_value} ->
        case validate(data, update_value) do
          {:ok, update_value} ->
            {get_value, update_value}

          # raise ArgumentError, message: inspect(error)
          {:error, error} ->
            meta = %{meta | defined?: false, errors: error ++ meta.errors}
            {get_value, %__MODULE__{data | __meta__: meta}}
        end
    end
  end

  def get_and_update(%__MODULE__{}, key, _),
    do: raise(BadStructError, struct: __MODULE__, term: key)

  #############################################################################
  @doc false
  @spec validation(data :: t()) :: (value() -> either())
  def validation(%__MODULE__{__meta__: %{optional?: true}, value: nil}), do: &{:ok, &1}

  def validation(%__MODULE__{validation: f}) when is_function(f, 1), do: &f.(&1)

  def validation(%__MODULE__{__context__: c, validation: f}) when is_function(f, 2),
    do: &f.(&1, c)

  def validation(%__MODULE__{}), do: &{:ok, &1}

  @doc false
  @spec validate(t()) :: {:ok, t()} | {:error, term()}
  def validate(%__MODULE__{value: value} = data), do: validate(data, value)

  def validate(%__MODULE__{__meta__: %{optional?: true} = meta} = data, nil) do
    if Tyyppi.of_type?(data.type, nil) do
      {:ok, %__MODULE__{data | __meta__: Map.put(meta, :defined?, true), value: nil}}
    else
      {:error, [type: [expected: to_string(data.type), got: nil]]}
    end
  end

  def validate(meta() = data, value) do
    with {:coercion, {:ok, cast}} <- {:coercion, data.coercion.(value)},
         true <- Tyyppi.of_type?(data.type, cast),
         {:validation, {:ok, value}} <- {:validation, validation(data).(cast)} do
      {:ok, %__MODULE__{data | __meta__: Map.put(meta, :defined?, true), value: value}}
    else
      false ->
        {:error, [type: [expected: to_string(data.type), got: value]]}

      {operation, {:error, error}} ->
        {:error, [{operation, [message: error, got: value]}]}
    end
  end

  @doc false
  @spec valid?(t()) :: boolean()
  def valid?(meta()) when meta.defined? == true, do: true
  def valid?(_), do: false

  @doc false
  @spec generation(t()) :: generator()
  def generation(%__MODULE__{generation: {g, params}}) when is_function(g, 1), do: g.(params)
  def generation(%__MODULE__{generation: g} = data) when is_function(g, 1), do: g.(data)
  def generation(%__MODULE__{generation: g}) when is_function(g, 0), do: g.()

  @spec value_type?(nil | Tyyppi.T.t(wrapped)) :: boolean() when wrapped: term()
  @doc false
  def value_type?(%Tyyppi.T{module: Tyyppi.Value, name: :t}), do: true
  def value_type?(_), do: false

  @doc "Helper guard to match Value instances"
  defguard is_value(value) when is_map(value) and value.__struct__ == Tyyppi.Value

  @spec value?(any()) :: boolean()
  @doc false
  def value?(%Tyyppi.Value{}), do: true
  def value?(_), do: false

  #############################################################################

  @type factory_option ::
          {:value, any()}
          | {:documentation, String.t()}
          | {:type, Tyyppi.T.t(term())}
          | {:coercion, coercer()}
          | {:validation, validator()}
          | {:encoding, encoder()}
          | {:generation, {generator(), any()} | generator() | nil}

  @keys ~w|value documentation type coercion validation encoding generation|a

  @spec any() :: t()
  @doc "Creates a not defined `any()` wrapped by `Tyyppi.Value`"
  def any,
    do: %Tyyppi.Value{
      type: Tyyppi.parse(any()),
      coercion: &Coercions.any/1,
      generation: &Generations.any/0
    }

  @spec any(any() | [factory_option()]) :: t()
  @doc "Factory for `any()` wrapped by `Tyyppi.Value`"
  def any([{:value, _} | _] = options), do: put_options(any(), options)
  def any([{:documentation, _} | _] = options), do: put_options(any(), options)
  def any(any), do: any(value: any)

  @spec atom() :: t()
  @doc "Creates a not defined `atom()` wrapped by `Tyyppi.Value`"
  def atom,
    do: %Tyyppi.Value{
      type: Tyyppi.parse(atom()),
      coercion: &Coercions.atom/1,
      generation: {&Generations.atom/1, :alphanumeric}
    }

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
  def boolean,
    do: %Tyyppi.Value{
      type: Tyyppi.parse(boolean()),
      coercion: &Coercions.boolean/1,
      generation: &Generations.boolean/0
    }

  @spec boolean(options :: any() | [factory_option()]) :: t()
  @doc "Factory for `boolean()` wrapped by `Tyyppi.Value`"
  def boolean(options) when is_list(options), do: put_options(boolean(), options)
  def boolean(boolean), do: boolean(value: boolean)

  @spec integer() :: t()
  @doc "Creates a not defined `integer()` wrapped by `Tyyppi.Value`"
  def integer,
    do: %Tyyppi.Value{
      type: Tyyppi.parse(integer()),
      coercion: &Coercions.integer/1,
      generation: &Generations.integer/0
    }

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
      validation: &Validations.non_neg_integer/1,
      generation: &Generations.non_neg_integer/0
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
      validation: &Validations.pos_integer/1,
      generation: &Generations.pos_integer/0
    }

  @spec pos_integer(options :: any() | [factory_option()]) :: t()
  @doc "Factory for `pos_integer()` wrapped by `Tyyppi.Value`"
  def pos_integer(options) when is_list(options), do: put_options(pos_integer(), options)
  def pos_integer(pos_integer), do: pos_integer(value: pos_integer)

  @spec date_time() :: t()
  @doc "Creates a not defined `date_time()` wrapped by `Tyyppi.Value`"
  def date_time,
    do: %Tyyppi.Value{
      type: Tyyppi.parse(DateTime.t()),
      coercion: &Coercions.date_time/1,
      generation: &Generations.date_time/0
    }

  @spec date_time(options :: any() | [factory_option()]) :: t()
  @doc "Factory for `timeout()` wrapped by `Tyyppi.Value`"
  def date_time(options) when is_list(options), do: put_options(date_time(), options)
  def date_time(date_time), do: date_time(value: date_time)

  @spec timeout() :: t()
  @doc "Creates a not defined `timeout()` wrapped by `Tyyppi.Value`"
  def timeout,
    do: %Tyyppi.Value{
      type: Tyyppi.parse(timeout()),
      coercion: &Coercions.timeout/1,
      validation: &Validations.timeout/1,
      generation: &Generations.timeout/0
    }

  @spec timeout(options :: any() | [factory_option()]) :: t()
  @doc "Factory for `timeout()` wrapped by `Tyyppi.Value`"
  def timeout(options) when is_list(options), do: put_options(timeout(), options)
  def timeout(timeout), do: timeout(value: timeout)

  @spec pid() :: t()
  @doc "Creates a not defined `pid()` wrapped by `Tyyppi.Value`"
  def pid,
    do: %Tyyppi.Value{
      type: Tyyppi.parse(pid()),
      coercion: &Coercions.pid/1,
      encoding: &Encodings.pid/2,
      generation: &Generations.pid/0
    }

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
      validation: &Validations.mfa/2,
      coercion: &Coercions.mfa/1,
      generation: &Generations.mfa/1
    }

  @spec mfa(
          options ::
            boolean()
            | function()
            | {module(), atom(), non_neg_integer()}
            | [{:existing, boolean()} | factory_option()]
        ) :: t()
  @doc "Factory for `mfa` wrapped by `Tyyppi.Value`"
  def mfa(existing) when is_boolean(existing),
    do: %Tyyppi.Value{mfa() | __context__: %{existing: existing}}

  def mfa(options) when is_list(options) do
    {existing, options} = Keyword.pop(options, :existing, false)
    existing |> mfa() |> put_options(options)
  end

  def mfa(fun) when is_function(fun), do: put_in(mfa(), [:value], fun)
  def mfa(mfa), do: mfa(value: mfa)

  @spec mfa(m :: module(), f :: atom(), a :: non_neg_integer()) :: t()
  @doc "Factory for `mfa` wrapped by `Tyyppi.Value`"
  def mfa(m, f, a), do: mfa(value: {m, f, a})

  @spec mod_arg() :: t()
  @doc "Creates a not defined `mod_arg` wrapped by `Tyyppi.Value`"
  def mod_arg,
    do: %Tyyppi.Value{
      type: Tyyppi.parse({module(), list()}),
      validation: &Validations.mod_arg/2,
      generation: &Generations.mod_arg/1
    }

  @spec mod_arg(
          options :: boolean() | {module(), list()} | [{:existing, boolean()} | factory_option()]
        ) :: t()
  @doc "Factory for `mod_arg` wrapped by `Tyyppi.Value`"
  def mod_arg(existing) when is_boolean(existing),
    do: %Tyyppi.Value{mod_arg() | __context__: %{existing: existing}}

  def mod_arg(options) when is_list(options) do
    {existing, options} = Keyword.pop(options, :existing, false)
    existing |> mod_arg() |> put_options(options)
  end

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
      validation: &Validations.fun/2,
      generation: &Generations.fun/1
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

  @spec do_one_of(keyword()) :: t()
  defp do_one_of(options) when is_list(options) do
    {allowed, options} = Keyword.pop(options, :allowed, [])
    allowed |> one_of() |> put_options(options)
  end

  @spec one_of([any()]) :: t()
  @doc "Creates a `one_of` value wrapped by `Tyyppi.Value`"
  def one_of([{:value, _} | _] = options), do: do_one_of(options)
  def one_of([{:documentation, _} | _] = options), do: do_one_of(options)
  def one_of([{:allowed, _} | _] = options), do: do_one_of(options)

  def one_of(allowed) when is_list(allowed),
    do: %Tyyppi.Value{
      type: Tyyppi.parse(any()),
      validation: &Validations.one_of/2,
      generation: &Generations.one_of/1,
      __context__: %{allowed: allowed}
    }

  @spec one_of(any(), [any()]) :: t()
  def one_of(value, allowed), do: allowed |> one_of() |> put_in([:value], value)

  @spec formulae() :: t()
  @doc "Creates a not defined `formulae` wrapped by `Tyyppi.Value`"
  def formulae,
    do: %Tyyppi.Value{
      type: Tyyppi.parse(any()),
      validation: &Validations.formulae/2,
      generation: &Generations.formulae/1
    }

  @doc "Factory for `formulae` wrapped by `Tyyppi.Value`"
  case Code.ensure_compiled(Formulae) do
    {:module, Formulae} ->
      @spec formulae(
              value :: any(),
              formulae :: Formulae.t() | binary() | {module(), atom(), list()}
            ) :: t()

      def formulae(value, {mod, fun, args}),
        do: formulae(value: value, formulae: {mod, fun, args})

      def formulae(value, formulae), do: formulae(value: value, formulae: formulae)

      @spec formulae(
              options ::
                Formulae.t() | binary() | [{:formulae, any()} | factory_option()]
            ) ::
              t()
      def formulae(formulae)
          when is_binary(formulae) or (is_map(formulae) and formulae.__struct__ == Formulae),
          do: %Tyyppi.Value{formulae() | __context__: %{formulae: Formulae.compile(formulae)}}

    _ ->
      @spec formulae(
              value :: any(),
              formulae :: binary() | {module(), atom(), list()}
            ) :: t()
      def formulae(value, {mod, fun, args}),
        do: formulae(value: value, formulae: {mod, fun, args})

      @spec formulae(options :: binary() | [{:formulae, any()} | factory_option()]) :: t()
  end

  def formulae({mod, fun, args}),
    do: %Tyyppi.Value{formulae() | __context__: %{formulae: {mod, fun, args}}}

  def formulae(options) when is_list(options) do
    {formulae, options} = Keyword.pop(options, :formulae, [])
    formulae |> formulae() |> put_options(options)
  end

  @spec list() :: t()
  @doc "Creates a not defined `list` wrapped by `Tyyppi.Value`"
  def list,
    do: %Tyyppi.Value{
      type: Tyyppi.parse(list()),
      validation: &Validations.list/2,
      generation: &Generations.list/1,
      __context__: %{type: Tyyppi.parse(any())}
    }

  @spec list(options :: Tyyppi.T.t(wrapped) | [{:type, Tyyppi.T.t(wrapped)} | factory_option()]) ::
          t(wrapped)
        when wrapped: term()
  @doc "Factory for `list` wrapped by `Tyyppi.Value`"
  def list(%Tyyppi.T{} = type), do: %Tyyppi.Value{list() | __context__: %{type: type}}

  def list(options) when is_list(options) do
    {type, options} = Keyword.pop(options, :type, [])
    type |> list() |> put_options(options)
  end

  @spec list(value :: list(), type :: Tyyppi.T.t(wrapped)) :: t(wrapped) when wrapped: term()
  def list(value, %Tyyppi.T{} = type) when is_list(value), do: list(value: value, type: type)

  @spec struct() :: t()
  @doc "Creates a not defined `struct` wrapped by `Tyyppi.Value`"
  def struct,
    do: %Tyyppi.Value{
      type: Tyyppi.parse(struct()),
      validation: &Validations.struct/1,
      generation: &Generations.struct/1
    }

  @spec struct(options :: [factory_option()]) :: t()
  @doc "Factory for `struct` wrapped by `Tyyppi.Value`"
  def struct(options) when is_list(options), do: Value.struct() |> put_options(options)

  @spec struct(value :: struct()) :: t()
  def struct(%_ts{} = value), do: Value.struct(value: value)

  #############################################################################

  @spec put_options(acc :: t(), options :: [factory_option()]) :: t()
  defp put_options(acc, options) do
    {result, unknowns} =
      Enum.reduce(options, {acc, []}, fn
        {k, v}, {acc, unknowns} when k in @keys ->
          {put_in(acc, [k], v), unknowns}

        {k, _}, {acc, unknowns} ->
          {acc, [k | unknowns]}
      end)

    unless unknowns == [] do
      raise("Unknown keys #{inspect(unknowns)} were ignored in `Value` constructor")
    end

    result
  end

  @spec optional(Value.t(wrapped)) :: Value.t(wrapped) when wrapped: term()
  def optional(%Value{__meta__: meta} = value) do
    type = Tyyppi.parse_quoted({:|, [], [nil, value.type.quoted]})
    generation = {&Generations.optional/1, value.generation}
    meta = %{meta | optional?: true}
    %Value{value | type: type, generation: generation, __meta__: meta}
  end

  #############################################################################

  if Code.ensure_loaded?(Jason.Encoder) do
    defimpl Jason.Encoder do
      @moduledoc false
      alias Jason.Encoder, as: E

      def encode(%Tyyppi.Value{__meta__: %{defined?: false}}, opts), do: E.encode(nil, opts)
      def encode(%Tyyppi.Value{encoding: nil, value: value}, opts), do: E.encode(value, opts)
      def encode(%Tyyppi.Value{encoding: encoder, value: value}, opts), do: encoder.(value, opts)
    end
  end

  defimpl Inspect do
    @moduledoc false
    import Inspect.Algebra

    def inspect(%Tyyppi.Value{value: value, __meta__: %{errors: errors}}, opts)
        when length(errors) > 0 do
      concat(["‹✗ #{inspect(Keyword.keys(errors))} ", to_doc(value, opts), "›"])
    end

    def inspect(%Tyyppi.Value{value: value, __meta__: %{defined?: true}}, opts) do
      concat(["‹", to_doc(value, opts), "›"])
    end

    def inspect(%Tyyppi.Value{value: value}, opts) do
      concat(["‹‽ ", to_doc(value, opts), "›"])
    end
  end
end
