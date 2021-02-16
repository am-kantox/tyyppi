defmodule Tyyppi.Value.Generations do
  @moduledoc false

  @prop_test Application.get_env(:tyyppi, :prop_testing_backend, StreamData)

  alias Tyyppi.Value

  def prop_test, do: @prop_test

  def any, do: @prop_test.term()

  def atom(kind \\ :alphanumeric) when is_atom(kind),
    do: kind |> @prop_test.atom() |> @prop_test.map(&Value.atom/1)

  def string, do: @prop_test.binary() |> @prop_test.map(&Value.string/1)

  def string(options) when is_list(options),
    do: options |> @prop_test.binary() |> @prop_test.map(&Value.string/1)

  def boolean, do: @prop_test.boolean() |> @prop_test.map(&Value.boolean/1)

  def integer, do: @prop_test.integer() |> @prop_test.map(&Value.integer/1)
  def integer(_.._ = range), do: range |> @prop_test.integer() |> @prop_test.map(&Value.integer/1)

  def non_neg_integer,
    do: @prop_test.integer() |> @prop_test.map(&abs(&1)) |> @prop_test.map(&Value.integer/1)

  def non_neg_integer(top) when is_integer(top) and top > 0, do: integer(0..top)

  def pos_integer, do: @prop_test.positive_integer() |> @prop_test.map(&Value.pos_integer/1)
  def pos_integer(top) when is_integer(top) and top > 0, do: integer(1..top)

  def date_time,
    do: @prop_test.integer() |> @prop_test.map(&abs(&1)) |> @prop_test.map(&Value.date_time/1)

  def timeout,
    do:
      @prop_test.one_of([non_neg_integer(), @prop_test.constant(:infinity)])
      |> @prop_test.map(&Value.timeout/1)

  def timeout(top) when is_integer(top) and top > 0,
    do:
      @prop_test.one_of([integer(0..top), @prop_test.constant(:infinity)])
      |> @prop_test.map(&Value.timeout/1)

  def pid, do: pid(0..4096)

  def pid(l..r) do
    @prop_test.bind(@prop_test.constant(0), fn p1 ->
      @prop_test.bind(@prop_test.integer(l..r), fn p2 ->
        @prop_test.bind(@prop_test.integer(l..r), fn p3 ->
          @prop_test.constant(Value.pid(p1, p2, p3))
        end)
      end)
    end)
  end

  def mfa(options \\ [])
  def mfa(%{} = options), do: options |> Map.to_list() |> mfa()

  def mfa(options) do
    max_arity = Keyword.get(options, :max_arity, 12)
    existing = Keyword.get(options, :existing, false)

    @prop_test.bind(@prop_test.atom(:alias), fn mod ->
      @prop_test.bind(@prop_test.atom(:alphanumeric), fn fun ->
        @prop_test.bind(@prop_test.integer(0..max_arity), fn arity ->
          @prop_test.constant(Value.mfa(value: {mod, fun, arity}, existing: existing))
        end)
      end)
    end)
  end

  def mod_arg(options \\ [])
  def mod_arg(%{} = options), do: options |> Map.to_list() |> mod_arg()

  def mod_arg(options) do
    args_generator = Keyword.get(options, :args_gen, @prop_test.list_of(@prop_test.term()))
    max_args_length = Keyword.get(options, :args_len, 12)
    existing = Keyword.get(options, :existing, false)

    @prop_test.bind(@prop_test.atom(:alias), fn mod ->
      @prop_test.bind(
        @prop_test.list_of(args_generator, max_length: max_args_length),
        fn params ->
          @prop_test.constant(Value.mod_arg(value: {mod, params}, existing: existing))
        end
      )
    end)
  end

  defmodule FunStubs do
    @moduledoc false
    Enum.each(0..12, fn arity ->
      args = Macro.generate_arguments(arity, __MODULE__)
      def f(unquote_splicing(args)), do: :ok
    end)
  end

  def fun(options \\ [])
  def fun(%{} = options), do: options |> Map.to_list() |> fun()

  def fun(options) do
    options
    |> Keyword.get(:arity, Enum.to_list(0..12))
    |> List.wrap()
    |> Enum.map(&Function.capture(FunStubs, :f, &1))
    |> Enum.map(&Value.fun/1)
    |> Enum.map(&@prop_test.constant/1)
    |> @prop_test.one_of()
  end

  def one_of(options \\ [])
  def one_of(%{} = options), do: options |> Map.to_list() |> one_of()

  def one_of(options) do
    options
    |> Keyword.get(:allowed, [])
    |> Enum.map(&Value.one_of/1)
    |> Enum.map(&@prop_test.constant/1)
    |> @prop_test.one_of()
  end

  def formulae(_options), do: raise("Not Implemented")
  def list(_options), do: raise("Not Implemented")
  def struct(_options), do: raise("Not Implemented")

  def optional(generation) when is_function(generation, 0),
    do: @prop_test.bind(generation.(), &@prop_test.constant(Enum.random([&1, nil])))

  def optional({generation, params}) when is_function(generation, 1),
    do: @prop_test.bind(generation.(params), &@prop_test.constant(Enum.random([&1, nil])))
end
