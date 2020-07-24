defmodule Tyyppi.Struct do
  import Kernel, except: [defstruct: 1]

  alias Tyyppi.T
  require T

  @moduledoc """
  Creates the typed struct with spec bound to each field.

  ## Usage

  See `Tyyppi.Example` for the example of why and how to use `Tyyppi.Struct`.

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

      iex> %Tyyppi.Example{}
      %Tyyppi.Example{
        bar: :erlang.list_to_pid('<0.0.0>'),
        baz: {:error, :reason}, foo: :default}

  ## Upserts

      iex> {ex, pid} = {%Tyyppi.Example{}, :erlang.list_to_pid('<0.0.0>')}
      iex> Tyyppi.Example.update(ex, foo: :foo, bar: {:ok, pid}, baz: :ok)
      {:ok, %Tyyppi.Example{
        bar: {:ok, :erlang.list_to_pid('<0.0.0>')},
        baz: :ok,
        foo: :foo}}
      iex> Tyyppi.Example.update(ex, foo: :foo, bar: {:ok, pid}, baz: 42)
      {:error, {:baz, :type}}

  ## `Access`

      iex> pid = :erlang.list_to_pid('<0.0.0>')
      iex> ex = %Tyyppi.Example{foo: :foo, bar: {:ok, pid}, baz: :ok}
      iex> put_in(ex, [:foo], :foo_sna)
      %Tyyppi.Example{
        bar: {:ok, :erlang.list_to_pid('<0.0.0>')},
        baz: :ok,
        foo: :foo_sna}
      iex> put_in(ex, [:foo], 42)
      ** (ArgumentError) could not put/update key :foo with value 42; reason: validation failed ({:foo, :type})

  """
  @doc false
  defmacro defstruct(definition) when is_list(definition) do
    typespec = typespec(definition)
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

    declaration =
      quote do
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
        @spec types :: [{atom(), Tyyppi.T.t()}]
        def types do
          Enum.map(@quoted_types, fn
            {k, %Tyyppi.T{definition: nil, quoted: quoted}} -> {k, Tyyppi.T.parse_quoted(quoted)}
            user -> user
          end)
        end

        defaults = Module.get_attribute(__MODULE__, :defaults, [])
        struct_declaration = Enum.map(@fields, &{&1, Keyword.get(defaults, &1)})

        Kernel.defstruct(struct_declaration)

        use Tyyppi.Access, @fields
      end

    validation =
      quote do
        @doc """
        This function is supposed to be overwritten in the implementation in cases
          when custom validation is required.

        It would be called after all casts and type validations, if the succeeded
        """
        @spec validate(t()) :: {:ok, t()} | {:error, term()}
        def validate(%__MODULE__{} = t), do: {:ok, t}

        defoverridable validate: 1
      end

    casts =
      quote bind_quoted: [] do
        funs =
          Enum.map(@fields, fn field ->
            @doc false
            def unquote(:"cast_#{field}")(value), do: value

            {:"cast_#{field}", 1}
          end)

        @doc false
        @spec do_cast(field :: atom(), value :: any()) :: any()
        defp do_cast(field, value), do: apply(__MODULE__, :"cast_#{field}", [value])

        defoverridable funs
      end

    update =
      quote bind_quoted: [] do
        @doc """
        Updates the struct
        """
        @spec update(target :: t(), values: keyword()) :: {:ok, t()} | {:error, term()}
        def update(%__MODULE__{} = target, values) when is_list(values) do
          types = types()

          values =
            Enum.reduce_while(values, [], fn {field, value}, acc ->
              cast = do_cast(field, value)

              if Tyyppi.of_type?(types[field], cast),
                do: {:cont, [{field, cast} | acc]},
                else: {:halt, {:error, {field, :type}}}
            end)

          with update when is_list(update) <- values,
               candidate = Map.merge(target, Map.new(update)),
               {:ok, result} <- validate(candidate),
               do: {:ok, result}
        end
      end

    [declaration, validation, casts, update]
  end

  @doc "Puts the value to target under specified key, if passes validation"
  @spec put(target :: struct, key :: atom(), value :: any()) :: {:ok, struct} | {:error, any()}
        when struct: %{__struct__: atom()}
  def put(%type{} = target, key, value) when is_atom(key), do: type.update(target, [{key, value}])

  @doc "Puts the value to target under specified key, if passes validation, raises otherwise"
  @spec put!(target :: struct, key :: atom(), value :: any()) :: struct | no_return()
        when struct: %{__struct__: atom()}
  def put!(%_type{} = target, key, value) when is_atom(key) do
    case put(target, key, value) do
      {:ok, data} ->
        data

      {:error, reason} ->
        raise(ArgumentError,
          message:
            "could not put/update key :#{key} with value #{inspect(value)}; reason: validation failed (#{
              inspect(reason)
            })"
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

  @spec typespec(atom: Macro.t()) :: {:%{}, [], [...]}
  defp typespec(types) do
    Enum.map(types, fn
      {k, type} when is_atom(type) ->
        {k, {type, [], []}}

      {k, {{_, _, _} = module, type}} ->
        {k, {{:., [], [module, type]}, [], []}}

      {k, {module, type}} when is_atom(module) and is_atom(type) ->
        modules = module |> Module.split() |> Enum.map(&:"#{&1}")
        {k, {{:., [], [{:__aliases__, [alias: false], modules}, type]}, [], []}}

      {k, v} ->
        {k, v}
    end)
  end
end
