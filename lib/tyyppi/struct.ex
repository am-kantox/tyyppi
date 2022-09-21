defmodule Tyyppi.Struct do
  import Kernel, except: [defstruct: 1]

  alias Tyyppi.{T, Value}
  require T

  @moduledoc """
  Creates the typed struct with spec bound to each field.

  ## Usage

  See `Tyyppi.Example.Struct` for the example of why and how to use `Tyyppi.Struct`.

  ### Example

      iex> defmodule MyStruct do
      ...>   @type my_type :: :ok | {:error, term()}
      ...>   Tyyppi.Struct.defstruct foo: atom(), bar: GenServer.on_start(), baz: my_type()
      ...> end
      iex> types = MyStruct.types()
      ...> types[:foo]
      %Tyyppi.T{
        definition: {:type, 0, :atom, []},
        module: nil,
        name: nil,
        params: [],
        source: nil,
        type: :built_in
      }
      ...> types[:baz]
      %Tyyppi.T{
        definition: {:type, 0, :union, [
          {:atom, 0, :ok},
          {:type, 0, :tuple, [
            {:atom, 0, :error}, {:type, 0, :term, []}]}]},
        module: Test.Tyyppi.Struct.MyStruct,
        name: :my_type,
        params: [],
        quoted: {{:., [], [Test.Tyyppi.Struct.MyStruct, :my_type]}, [], []},
        source: :user_type,
        type: :type
      }

  ## Defaults

  Since there is no place for default values in the struct declaration, where types
    are first class citizens, defaults might be specified through `@defaults` module
    attribute. Omitted fields there will be considered having `nil` default value.

      iex> %Tyyppi.Example.Struct{}
      %Tyyppi.Example.Struct{
        bar: {:ok, :erlang.list_to_pid('<0.0.0>')}, baz: {:error, :reason}, foo: nil}

  ## Upserts

      iex> {ex, pid} = {%Tyyppi.Example.Struct{}, :erlang.list_to_pid('<0.0.0>')}
      iex> Tyyppi.Example.Struct.update(ex, foo: :foo, bar: {:ok, pid}, baz: :ok)
      {:ok, %Tyyppi.Example.Struct{
        bar: {:ok, :erlang.list_to_pid('<0.0.0>')},
        baz: :ok,
        foo: :foo}}
      iex> Tyyppi.Example.Struct.update(ex, foo: :foo, bar: {:ok, pid}, baz: 42)
      {:error, [baz: [type: [expected: "Tyyppi.Example.Struct.my_type()", got: 42]]]}

  ## `Access`

      iex> pid = :erlang.list_to_pid('<0.0.0>')
      iex> ex = %Tyyppi.Example.Struct{foo: :foo, bar: {:ok, pid}, baz: :ok}
      iex> put_in(ex, [:foo], :foo_sna)
      %Tyyppi.Example.Struct{
        bar: {:ok, :erlang.list_to_pid('<0.0.0>')},
        baz: :ok,
        foo: :foo_sna}
      iex> put_in(ex, [:foo], 42)
      ** (ArgumentError) could not put/update key :foo with value 42 ([foo: [type: [expected: \"atom()\", got: 42]]])

  """
  @doc """
  Declares a typed struct. The accepted argument is the keyword of
  `{field_name, type}` tuples. See `Tyyppi.Example.Struct` for an example.
  """
  defmacro defstruct(definition) when is_list(definition) do
    typespec = typespec(definition, __CALLER__)
    struct_typespec = [{:__struct__, {:__MODULE__, [], Elixir}} | typespec]

    quoted_types =
      quote bind_quoted: [definition: Macro.escape(definition)] do
        # FIXME Private types
        user_type = fn {type, _, _} ->
          __MODULE__
          |> Module.get_attribute(:type)
          |> Enum.find(&match?({_, {:"::", _, [{^type, _, _} | _]}, _}, &1))
          |> case do
            nil ->
              nil

            {kind, {:"::", _, [{type, _, params}, definition]}, _} ->
              params = T.normalize_params(params)
              param_names = T.param_names(params)

              %T{
                T.parse_quoted(definition)
                | type: kind,
                  module: __MODULE__,
                  name: type,
                  params: params,
                  source: :user_type,
                  quoted:
                    quote(do: unquote(__MODULE__).unquote(type)(unquote_splicing(param_names)))
                    |> Macro.prewalk(fn
                      {id, meta, params} when is_list(meta) ->
                        {id, Enum.reject(meta, &match?({:generated, true}, &1)), params}

                      other ->
                        other
                    end)
              }
          end
        end

        Enum.map(definition, fn {key, type} ->
          {key, user_type.(type) || %T{quoted: type}}
        end)
      end

    declaration = do_declaration(quoted_types, struct_typespec, __CALLER__.line)
    validation = do_validation()
    casts_and_validates = do_casts_and_validates()
    update = do_update()
    generation = do_generation()
    mod = Macro.expand(__CALLER__.module, __ENV__)
    as_value = do_as_value(Macro.escape(T.parse_quoted({{:., [], [mod, :t]}, [], []})))
    collectable = do_collectable()
    enumerable = do_enumerable()

    jason =
      if Application.get_env(:tyyppi, :jason, false) or Code.ensure_loaded?(Jason.Encoder),
        do: quote(do: @derive(Jason.Encoder)),
        else: []

    flatten =
      quote do
        defdelegate flatten(struct), to: Tyyppi.Struct
        defdelegate flatten(struct, opts), to: Tyyppi.Struct
      end

    [
      jason,
      declaration,
      validation,
      casts_and_validates,
      update,
      generation,
      as_value,
      collectable,
      enumerable,
      flatten
    ]
  end

  @doc "Puts the value to target under specified key, if passes validation"
  @spec put(target :: struct, key :: atom(), value :: any()) ::
          {:ok, struct} | {:error, keyword()}
        when struct: %{required(atom()) => any()}
  def put(%type{} = target, key, value) when is_atom(key), do: type.update(target, [{key, value}])

  @doc "Puts the value to target under specified key, if passes validation, raises otherwise"
  @spec put!(target :: struct, key :: atom(), value :: any()) :: struct
        when struct: %{required(atom()) => any()}
  def put!(%_type{} = target, key, value) when is_atom(key) do
    case put(target, key, value) do
      {:ok, data} ->
        data

      {:error, error} ->
        raise(ArgumentError,
          message:
            "could not put/update key :#{key} with value #{inspect(value)} (#{inspect(error)})"
        )
    end
  end

  @doc "Updates the value in target under specified key, if passes validation"
  @spec update(target :: struct, key :: atom(), updater :: (any() -> any())) ::
          {:ok, struct} | {:error, any()}
        when struct: %{__struct__: atom()}
  def update(%_type{} = target, key, fun) when is_atom(key) and is_function(fun, 1),
    do: put(target, key, fun.(target[key]))

  @doc "Updates the value in target under specified key, if passes validation, raises otherwise"
  @spec update!(target :: struct, key :: atom(), updater :: (any() -> any())) ::
          struct | no_return()
        when struct: %{__struct__: atom()}
  def update!(%_type{} = target, key, fun) when is_atom(key) and is_function(fun, 1),
    do: put!(target, key, fun.(target[key]))

  @doc false
  @spec typespec(types :: {atom(), T.ast()} | [{atom(), T.ast()}], Macro.Env.t()) ::
          {atom(), T.ast()} | [{atom(), T.ast()}]
  def typespec({k, type}, _env) when is_atom(type), do: {k, {type, [], []}}

  def typespec({k, {{:., meta, [aliases, type]}, submeta, args}}, env) when is_atom(type),
    do: {k, {{:., meta, [Macro.expand(aliases, env), type]}, submeta, args}}

  def typespec({k, {module, type}}, env) when is_atom(module) and is_atom(type) do
    modules = module |> Module.split() |> Enum.map(&:"#{&1}")
    {k, {{:., [], [Macro.expand({:__aliases__, [], modules}, env), type]}, [], []}}
  end

  def typespec({k, type}, _env), do: {k, type}

  def typespec(types, env) when is_list(types),
    do: Enum.map(types, &typespec(&1, env))

  #############################################################################
  defp do_declaration(quoted_types, struct_typespec, line) do
    quote generated: true, location: :keep do
      if is_nil(Module.get_attribute(__MODULE__, :moduledoc)) do
        Module.put_attribute(
          __MODULE__,
          :moduledoc,
          {unquote(line),
           """
           The implementation of `Tyyppi.Struct`, exposing the type and `Access`
             implementation to deal with this object.
           """}
        )
      end

      alias Tyyppi.Struct

      @quoted_types unquote(quoted_types)
      @fields Keyword.keys(@quoted_types)

      @typedoc ~s"""
      The type describing `#{inspect(__MODULE__)}`. This type will be used to validate
        upserts when called via `Access` and/or `Tyyppi.Struct.put/3`,
        `Tyyppi.Struct.update/3`, both delegating to generated
        `#{inspect(__MODULE__)}.update/2`.

      Upon insertion, the value will be coerced to the expected type
        when available, the type itself will be validated, and then the
        custom validation will be applied when applicable.
      """
      @type t :: %{unquote_splicing(struct_typespec)}

      @doc ~s"""
      Returns the field types of this struct as keyword of
        `{field :: atom, type :: Tyyppi.T.t(term())}` pairs.
      """
      @spec types :: [{atom(), T.t(wrapped)}] when wrapped: term()
      def types do
        Enum.map(@quoted_types, fn
          {k, %T{definition: nil, quoted: quoted}} ->
            {^k, quoted} = Tyyppi.Struct.typespec({k, quoted}, __ENV__)
            {k, T.parse_quoted(quoted)}

          user ->
            user
        end)
      end

      # FIXME to check defaults we’ll need to create a blank struct and to `put_in/3`
      #       all the defaults in `__before_compile__/1`
      defaults = Module.get_attribute(__MODULE__, :defaults, [])
      struct_declaration = Enum.map(@fields, &{&1, Keyword.get(defaults, &1)})

      Kernel.defstruct(struct_declaration)

      use Tyyppi.Access, @fields
    end
  end

  defp do_validation do
    quote generated: true, location: :keep do
      @doc """
      This function is supposed to be overwritten in the implementation in cases
        when custom validation is required.

      It would be called after all casts and type validations, if the succeeded
      """
      @spec validate(t()) :: Tyyppi.Valuable.either()
      def validate(%__MODULE__{} = s) do
        s
        |> Enum.reduce({s, []}, fn
          {key, %type{} = value}, {%__MODULE__{} = acc, errors} ->
            if type.__info__(:functions)[:validate] == 1 do
              case type.validate(value) do
                {:ok, value} -> {Map.put(acc, key, value), errors}
                {:error, error} -> {acc, error ++ errors}
              end
            else
              {acc, errors}
            end

          {_, _}, {acc, errors} ->
            {acc, errors}
        end)
        |> case do
          {validated, []} -> {:ok, validated}
          {_, errors} -> {:error, errors}
        end
      end

      @spec errors(t()) :: list()
      def errors(%__MODULE__{} = s) do
        Enum.reduce(s, [], fn
          {key, %type{} = value}, errors ->
            if type.__info__(:functions)[:validate] == 1 do
              case type.validate(value) do
                {:ok, value} ->
                  if type.__info__(:functions)[:valid?] != 1 or type.valid?(value),
                    do: errors,
                    else: [{key, :invalid_value} | errors]

                {:error, error} ->
                  error ++ errors
              end
            else
              errors
            end

          {_, _}, errors ->
            errors
        end)
      end

      @spec valid?(t()) :: boolean()
      def valid?(%__MODULE__{} = s) do
        Enum.reduce_while(s, true, fn
          _, false ->
            {:halt, false}

          {_, %Tyyppi.Value{} = v}, true ->
            {:cont, Tyyppi.Value.valid?(v)}

          {_, %type{} = v}, true ->
            {:cont, type.__info__(:functions)[:valid?] == 1 && type.valid?(v)}

          _, true ->
            {:cont, true}
        end)
      end

      defoverridable validate: 1, valid?: 1
    end
  end

  defp do_collectable do
    quote generated: true, location: :keep, unquote: false do
      fields = @fields

      defimpl Collectable do
        @moduledoc false
        alias Tyyppi.Struct

        def into(original) do
          {original,
           fn
             acc, {:cont, {k, v}} when k in unquote(fields) -> Struct.put!(acc, k, v)
             acc, :done -> acc
             _, :halt -> :ok
           end}
        end
      end
    end
  end

  defp do_enumerable do
    quote generated: true, location: :keep, unquote: false do
      fields = @fields
      count = length(fields)

      defimpl Enumerable do
        @moduledoc false
        alias Tyyppi.Struct

        def slice(enumerable), do: {:error, __MODULE__}

        def count(_), do: {:ok, unquote(count)}

        def member?(map, {field, value}) when field in unquote(fields),
          do: {:ok, match?({:ok, ^value}, :maps.find(field, map))}

        def member?(_, _), do: {:ok, false}

        def reduce(map, acc, fun),
          do: do_reduce(map |> Map.from_struct() |> :maps.to_list(), acc, fun)

        defp do_reduce(_, {:halt, acc}, _fun), do: {:halted, acc}

        defp do_reduce(list, {:suspend, acc}, fun),
          do: {:suspended, acc, &do_reduce(list, &1, fun)}

        defp do_reduce([], {:cont, acc}, _fun), do: {:done, acc}
        defp do_reduce([h | t], {:cont, acc}, fun), do: do_reduce(t, fun.(h, acc), fun)
      end
    end
  end

  defp do_as_value({:%{}, [], [{:__struct__, Tyyppi.T} | rest]} = type) do
    quoted = Keyword.get(rest, :quoted, {:{}, [], [:any, [], []]})

    quote generated: true, location: :keep do
      @spec as_value(keyword()) :: Tyyppi.Value.t(unquote(quoted))
      @doc "Factory for `#{__MODULE__}` wrapped by `Tyyppi.Value`"
      def as_value(values \\ []) do
        value = struct!(__MODULE__, values)

        %Tyyppi.Value{
          value: value,
          type: unquote(type),
          validation: &__MODULE__.validate/1,
          generation: &__MODULE__.generation/1
        }
      end
    end
  end

  defp do_casts_and_validates do
    quote generated: true, location: :keep, unquote: false do
      funs =
        Enum.flat_map(@fields, fn field ->
          @doc false
          defp unquote(:"cast_#{field}")(value), do: value
          @doc false
          defp do_cast(unquote(field), value), do: unquote(:"cast_#{field}")(value)

          @doc false
          defp unquote(:"validate_#{field}")(value), do: {:ok, value}
          @doc false
          defp do_validate(unquote(field), value) do
            case :erlang.phash2(1, 1) do
              0 -> unquote(:"validate_#{field}")(value)
              1 -> {:error, :hack_to_fool_dialyzer}
            end
          end

          [{:"cast_#{field}", 1}, {:"validate_#{field}", 1}]
        end)

      defoverridable funs
    end
  end

  defp do_update do
    quote generated: true, location: :keep, unquote: false do
      @doc """
      Updates the struct
      """
      @spec update(target :: t(), values :: keyword()) :: {:ok, t()} | {:error, keyword()}
      def update(%__MODULE__{} = target, values) when is_list(values) do
        types = types()

        values =
          Enum.reduce(values, %{result: [], errors: []}, fn {field, value}, acc ->
            cast = do_cast(field, value)

            cast =
              case {Tyyppi.Value.value_type?(types[field]), match?(%Tyyppi.Value{}, cast), target} do
                {true, false, %{^field => %Tyyppi.Value{} = value}} ->
                  put_in(value, [:value], cast)

                _ ->
                  value = get_in(target, [field])

                  if T.collectable?(value) and T.enumerable?(cast),
                    do: Enum.into(cast, value),
                    else: cast
              end

            acc =
              cond do
                match?(%Tyyppi.Value{}, cast) and is_list(cast[:errors]) ->
                  %{acc | errors: [{field, cast[:errors]} | acc.errors]}

                Tyyppi.of_type?(types[field], cast) ->
                  case do_validate(field, cast) do
                    {:ok, result} ->
                      %{acc | result: [{field, cast} | acc.result]}

                    {:error, error} ->
                      %{
                        acc
                        | errors: [
                            {field, [validation: [message: error, got: value, cast: cast]]}
                            | acc.errors
                          ]
                      }
                  end

                true ->
                  error = {field, [type: [expected: to_string(types[field]), got: value]]}
                  %{acc | errors: [error | acc.errors]}
              end
          end)

        with %{result: update, errors: []} <- values,
             candidate = Map.merge(target, Map.new(update)),
             {:ok, result} <- validate(candidate) do
          {:ok, result}
        else
          %{errors: errors} -> {:error, errors}
          {:error, errors} -> {:error, errors}
        end
      end
    end
  end

  defp do_generation do
    quote generated: true, location: :keep, unquote: false do
      defp prop_test, do: quote(do: unquote(Tyyppi.Value.Generations.prop_test()))

      @dialyzer {:nowarn_function, generation_leaf: 1}
      defp generation_leaf(args),
        do: {{:., [], [prop_test(), :constant]}, [], [{:{}, [], args}]}

      @dialyzer {:nowarn_function, generation_clause: 3}
      defp generation_clause(this, {field, arg}, acc) do
        {{:., [], [prop_test(), :bind]}, [],
         [
           {{:., [], [{:__aliases__, [alias: false], [:Tyyppi, :Struct]}, :generation]}, [],
            [{{:., [], [this, field]}, [no_parens: true], []}]},
           {:fn, [], [{:->, [], [[arg], acc]}]}
         ]}
      end

      @dialyzer {:nowarn_function, generation_bound: 2}
      defp generation_bound(this, fields) do
        args = fields |> length() |> Macro.generate_arguments(__MODULE__) |> Enum.reverse()
        fields_args = Enum.zip(fields, args)

        Enum.reduce(fields_args, generation_leaf(args), &generation_clause(this, &1, &2))
      end

      defmacrop do_generation(this, fields),
        do: generation_bound(this, Macro.expand(fields, __CALLER__))

      @doc false
      @dialyzer {:nowarn_function, generation: 1}
      @spec generation(t()) :: Tyyppi.Valuable.generation()

      def generation(%Value{value: %__MODULE__{} = value}), do: generation(value)

      def generation(%__MODULE__{} = this) do
        prop_test = Value.Generations.prop_test()

        this
        |> do_generation(@fields)
        |> prop_test.map(&Tuple.to_list/1)
        |> prop_test.map(&Enum.zip(@fields, &1))
        |> prop_test.map(&Enum.into(&1, this))
      end

      defoverridable generation: 1
    end
  end

  ##############################################################################

  @behaviour Tyyppi.Valuable

  @impl Tyyppi.Valuable
  # FIXME
  def coerce(%_type{} = s), do: {:ok, s}

  @impl Tyyppi.Valuable
  def validate(%type{} = s), do: type.validate(s)

  @impl Tyyppi.Valuable
  def generation(%type{} = value), do: type.generation(value)

  @impl Tyyppi.Valuable
  def flatten(value, opts \\ [])

  def flatten(%Value{} = value, opts),
    do: Value.flatten(value, opts)

  def flatten(%_type{} = value, opts) do
    force = Keyword.get(opts, :force, true)
    squeeze = Keyword.get(opts, :squeeze, false)

    if is_nil(Enumerable.impl_for(value)) do
      value
    else
      result =
        Enum.reduce(value, %{}, fn
          {key, %Value{} = value}, acc ->
            value |> Value.flatten() |> flatten_once(acc, key, opts)

          {key, %subtype{} = value}, acc ->
            if force or Tyyppi.can_flatten?(subtype),
              do: value |> subtype.flatten() |> flatten_once(acc, key, opts),
              else: Map.put(acc, to_string(key), value)

          {key, value}, acc ->
            Map.put(acc, to_string(key), value)
        end)

      case squeeze do
        true ->
          Enum.reduce(result, %{}, fn
            {_, nil}, acc -> acc
            {k, v}, acc -> Map.put(acc, k, v)
          end)

        false ->
          result

        f when is_function(f, 1) ->
          Enum.reduce(result, %{}, fn {k, v}, acc ->
            case f.({k, v}) do
              {:ok, v} -> Map.put(acc, k, v)
              :squeeze -> acc
            end
          end)
      end
    end
  end

  defp flatten_once(value, acc, key, opts) do
    joiner = Keyword.get(opts, :joiner, "_")

    case value do
      %_type{} = struct ->
        if is_nil(Enumerable.impl_for(struct)) do
          Map.put(acc, to_string(key), Value.flatten(value, opts))
        else
          struct
          |> Map.new(fn {k, v} -> {Enum.join([key, k], joiner), Value.flatten(v, opts)} end)
          |> Map.merge(acc)
        end

      %{} = map ->
        map
        |> Map.new(fn {k, v} -> {Enum.join([key, k], joiner), Value.flatten(v, opts)} end)
        |> Map.merge(acc)

      _ ->
        Map.put(acc, to_string(key), Value.flatten(value, opts))
    end
  end
end
