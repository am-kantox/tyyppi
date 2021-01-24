defmodule Tyyppi.Struct do
  import Kernel, except: [defstruct: 1]

  alias Tyyppi.T
  require T

  @moduledoc """
  Creates the typed struct with spec bound to each field.

  ## Usage

  See `Tyyppi.ExamplePlainStruct` for the example of why and how to use `Tyyppi.Struct`.

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

      iex> %Tyyppi.ExamplePlainStruct{}
      %Tyyppi.ExamplePlainStruct{
        bar: :erlang.list_to_pid('<0.0.0>'), baz: {:error, :reason}, foo: nil}

  ## Upserts

      iex> {ex, pid} = {%Tyyppi.ExamplePlainStruct{}, :erlang.list_to_pid('<0.0.0>')}
      iex> Tyyppi.ExamplePlainStruct.update(ex, foo: :foo, bar: {:ok, pid}, baz: :ok)
      {:ok, %Tyyppi.ExamplePlainStruct{
        bar: {:ok, :erlang.list_to_pid('<0.0.0>')},
        baz: :ok,
        foo: :foo}}
      iex> Tyyppi.ExamplePlainStruct.update(ex, foo: :foo, bar: {:ok, pid}, baz: 42)
      {:error, [baz: [type: [expected: "Tyyppi.ExamplePlainStruct.my_type()", got: 42]]]}

  ## `Access`

      iex> pid = :erlang.list_to_pid('<0.0.0>')
      iex> ex = %Tyyppi.ExamplePlainStruct{foo: :foo, bar: {:ok, pid}, baz: :ok}
      iex> put_in(ex, [:foo], :foo_sna)
      %Tyyppi.ExamplePlainStruct{
        bar: {:ok, :erlang.list_to_pid('<0.0.0>')},
        baz: :ok,
        foo: :foo_sna}
      iex> put_in(ex, [:foo], 42)
      ** (ArgumentError) could not put/update key :foo with value 42 ([foo: [type: [expected: \"atom()\", got: 42]]])

  """
  @doc false
  defmacro defstruct(definition) when is_list(definition) do
    typespec = typespec(definition, __CALLER__)
    struct_typespec = [{:__struct__, {:__MODULE__, [], Elixir}} | typespec]

    quoted_types =
      quote bind_quoted: [definition: Macro.escape(definition)] do
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
              }
          end
        end

        Enum.map(definition, fn {key, type} ->
          {key, user_type.(type) || %T{quoted: type}}
        end)
      end

    declaration = do_declaration(quoted_types, struct_typespec)
    validation = do_validation()
    collectable = do_collectable()
    casts_and_validates = do_casts_and_validates()
    update = do_update()

    jason =
      if Code.ensure_loaded?(Jason.Encoder),
        do: [quote(do: @derive(Jason.Encoder))],
        else: []

    [declaration, validation, collectable, casts_and_validates, update, jason]
  end

  @doc "Puts the value to target under specified key, if passes validation"
  @spec put(target :: struct, key :: atom(), value :: any()) ::
          {:ok, struct} | {:error, keyword()}
        when struct: %{required(atom()) => any()}
  def put(%type{} = target, key, value) when is_atom(key), do: type.update(target, [{key, value}])

  @doc "Puts the value to target under specified key, if passes validation, raises otherwise"
  @dialyzer {:nowarn_function, put!: 3}
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

  def typespec({k, {{:., _, [aliases, type]}, _, args}}, env) when is_atom(type),
    do: {k, {{:., [], [Macro.expand(aliases, env), type]}, [], args}}

  def typespec({k, {module, type}}, env) when is_atom(module) and is_atom(type) do
    modules = module |> Module.split() |> Enum.map(&:"#{&1}")
    {k, {{:., [], [Macro.expand({:__aliases__, [], modules}, env), type]}, [], []}}
  end

  def typespec({k, type}, _env), do: {k, type}

  def typespec(types, env) when is_list(types),
    do: Enum.map(types, &typespec(&1, env))

  #############################################################################
  defp do_declaration(quoted_types, struct_typespec) do
    quote location: :keep do
      alias Tyyppi.Struct

      @quoted_types unquote(quoted_types)
      @fields Keyword.keys(@quoted_types)

      @typedoc ~s"""
      The type describing this struct. This type will be used to validate
        upserts when called via `Access` and/or `#{inspect(__MODULE__)}.put/3`,
        `#{inspect(__MODULE__)}.update/4`.
      """
      @type t :: %{unquote_splicing(struct_typespec)}

      @doc ~s"""
      Returns the field types of this struct as keyword of
        `{field :: atom, type :: Tyyppi.T.t()}` pairs.
      """
      @spec types :: [{atom(), T.t()}]
      def types do
        Enum.map(@quoted_types, fn
          {k, %T{definition: nil, quoted: quoted}} ->
            {^k, quoted} = Tyyppi.Struct.typespec({k, quoted}, __ENV__)
            {k, T.parse_quoted(quoted)}

          user ->
            user
        end)
      end

      defaults = Module.get_attribute(__MODULE__, :defaults, [])
      struct_declaration = Enum.map(@fields, &{&1, Keyword.get(defaults, &1)})

      Kernel.defstruct(struct_declaration)

      use Tyyppi.Access, @fields
    end
  end

  defp do_validation do
    quote location: :keep do
      @doc """
      This function is supposed to be overwritten in the implementation in cases
        when custom validation is required.

      It would be called after all casts and type validations, if the succeeded
      """
      @spec validate(t()) :: {:ok, t()} | {:error, term()}
      def validate(%__MODULE__{} = t), do: {:ok, t}

      defoverridable validate: 1
    end
  end

  defp do_collectable do
    quote location: :keep, unquote: false do
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

  defp do_casts_and_validates do
    quote location: :keep, unquote: false do
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
    quote location: :keep, unquote: false do
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
                  cast
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
             {:ok, result} <- validate(candidate),
             do: {:ok, result},
             else: (%{errors: errors} -> {:error, errors})
      end
    end
  end
end
