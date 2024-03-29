defmodule Test.Tyyppi.Value do
  use ExUnit.Case

  require Tyyppi
  alias Tyyppi.Value

  describe "generics" do
    test "value?" do
      assert :ok |> Value.any() |> Value.value?()
      refute Value.valid?(42)
    end

    test "value_type?" do
      assert Value.t() |> Tyyppi.parse() |> Value.value_type?()
      refute GenServer.on_start() |> Tyyppi.parse() |> Value.value_type?()
      refute integer() |> Tyyppi.parse() |> Value.value_type?()
    end

    test "valid?" do
      assert :ok |> Value.any() |> Value.valid?()
      refute Value.any() |> Value.valid?()
    end

    test "optional" do
      value = Value.integer(42)
      assert value |> put_in([:value], 0) |> Value.valid?()
      refute value |> put_in([:value], nil) |> Value.valid?()

      value = 42 |> Value.integer() |> Value.optional()
      assert value |> put_in([:value], 0) |> Value.valid?()
      assert value |> put_in([:value], nil) |> Value.valid?()
      refute value |> put_in([:value], :ok) |> Value.valid?()
    end

    test "validate" do
      ok = Value.atom(:ok)
      ko = %Value{Value.atom(:ok) | value: 42}
      assert Value.validate(ok)

      assert {:error, [coercion: [message: "Expected atom(), charlist() or binary()", got: 42]]} ==
               Value.validate(ko)
    end
  end

  describe "constructors" do
    test "any" do
      assert :ok == get_in(Value.any(:ok), [:value])
      assert "ok" == get_in(Value.any("ok"), [:value])
      assert 'ok' == get_in(Value.any('ok'), [:value])
    end

    test "atom" do
      assert :ok == get_in(Value.atom(:ok), [:value])
      assert :ok == get_in(Value.atom("ok"), [:value])
      assert :ok == get_in(Value.atom('ok'), [:value])

      assert %{__meta__: %{errors: [{:coercion, _error}]}} = Value.integer("42.1")
    end

    test "string" do
      assert "ok" == get_in(Value.string(:ok), [:value])
      assert "ok" == get_in(Value.string("ok"), [:value])
      assert "ok" == get_in(Value.string('ok'), [:value])

      assert %{__meta__: %{errors: [{:coercion, _error}]}} = Value.string(self())
    end

    test "boolean" do
      assert get_in(Value.boolean(:ok), [:value])
      assert get_in(Value.boolean(true), [:value])
      refute get_in(Value.boolean(false), [:value])
      refute get_in(Value.boolean(nil), [:value])
    end

    test "integer" do
      assert 42 == get_in(Value.integer(42), [:value])
      assert 42 == get_in(Value.integer("42"), [:value])
      assert 42 == get_in(Value.integer(42.1), [:value])

      assert %{__meta__: %{errors: [{:coercion, _error}]}} = Value.integer("42.1")
    end

    test "float" do
      assert 42.0 == get_in(Value.float(42), [:value])
      assert 42.0 == get_in(Value.float("42"), [:value])
      assert 42.1 == get_in(Value.float(42.1), [:value])
      assert 42.1 == get_in(Value.float("42.1"), [:value])

      assert %{__meta__: %{errors: [{:coercion, _error}]}} = Value.float("42.")
    end

    test "timeout / pos_integer" do
      assert 42 == get_in(Value.non_neg_integer(42), [:value])
      assert 42 == get_in(Value.non_neg_integer("42"), [:value])
      assert 42 == get_in(Value.non_neg_integer(42.1), [:value])
      assert 0 == get_in(Value.non_neg_integer(0), [:value])

      assert %{__meta__: %{errors: [type: [expected: "non_neg_integer()", got: -42]]}} =
               Value.non_neg_integer(-42)

      assert %{__meta__: %{errors: [type: [expected: "pos_integer()", got: 0]]}} =
               Value.pos_integer(0)
    end

    test "date" do
      assert is_nil(get_in(Value.date(42), [:value]))
      assert ~D[1973-09-30] == get_in(Value.date("1973-09-30"), [:value])
      assert ~D[1973-09-30] == get_in(Value.date("1973-09-30T00:00:00Z"), [:value])
      assert ~D[1973-09-30] == get_in(Value.date({1973, 9, 30}), [:value])

      assert %{
               __meta__: %{
                 errors: [
                   coercion: [
                     message: "Expected Date() or binary() or erlang date tuple.",
                     got: :ok
                   ]
                 ]
               }
             } = Value.date(:ok)
    end

    test "date_time" do
      assert ~U[1970-01-01 00:00:42Z] == get_in(Value.date_time(42), [:value])
      assert ~U[1973-09-30 02:46:30Z] == get_in(Value.date_time("1973-09-30T02:46:30Z"), [:value])
      assert ~U[1969-12-31 23:59:18Z] == get_in(Value.date_time(-42), [:value])

      assert %{
               __meta__: %{
                 errors: [
                   coercion: [message: "Expected DateTime() or binary() or integer().", got: :ok]
                 ]
               }
             } = Value.date_time(:ok)
    end

    test "timeout" do
      assert 42 == get_in(Value.timeout(42), [:value])
      assert 42 == get_in(Value.timeout("42"), [:value])
      assert 42 == get_in(Value.timeout(42.1), [:value])
      assert 0 == get_in(Value.timeout(0), [:value])
      assert :infinity == get_in(Value.timeout(:infinity), [:value])

      assert %{__meta__: %{errors: [type: [expected: "timeout()", got: -42]]}} =
               Value.timeout(-42)

      assert %{__meta__: %{errors: [coercion: [message: "Expected timeout()", got: :ok]]}} =
               Value.timeout(:ok)
    end

    test "pid" do
      this = self()

      ['<', p1, '.', p2, '.', p3, '>'] =
        this |> :erlang.pid_to_list() |> Enum.chunk_by(&(&1 in ?0..?9))

      assert this == get_in(Value.pid(this), [:value])
      assert this == get_in(Value.pid(:erlang.pid_to_list(this)), [:value])
      assert this == get_in(Value.pid(Enum.join([p1, p2, p3], ".")), [:value])
      assert this == get_in(Value.pid("<" <> Enum.join([p1, p2, p3], ".") <> ">"), [:value])
      assert this == get_in(Value.pid("#PID<" <> Enum.join([p1, p2, p3], ".") <> ">"), [:value])

      [p1, p2, p3] = [p1, p2, p3] |> Enum.map(&to_string/1) |> Enum.map(&String.to_integer/1)
      assert this == get_in(Value.pid(p1, p2, p3), [:value])

      assert %{
               __meta__: %{
                 errors: [
                   coercion: [message: "Expected a value that can be converted to pid()", got: 42]
                 ]
               }
             } = Value.pid(42)

      assert %{
               __meta__: %{
                 errors: [
                   coercion: [
                     message: "Expected a value that can be converted to pid()",
                     got: :ok
                   ]
                 ]
               }
             } = Value.pid(:ok)
    end

    test "mfa" do
      assert {Integer, :to_string, 2} == get_in(Value.mfa({Integer, :to_string, 2}), [:value])
      assert {Integer, :to_string, 1} == get_in(Value.mfa(Integer, :to_string, 1), [:value])

      assert %{
               __meta__: %{
                 errors: [coercion: [message: "Unexpected value for a function", got: -42]]
               }
             } = Value.mfa(-42)

      assert %{
               __meta__: %{
                 errors: [
                   validation: [
                     message: "Integer does not declare a function to_string of arity 0",
                     got: {Integer, :to_string, 0}
                   ]
                 ]
               }
             } = Value.mfa(value: {Integer, :to_string, 0}, existing: true)
    end

    test "mod_arg" do
      assert {Integer, []} == get_in(Value.mod_arg({Integer, []}), [:value])

      assert {Integer, [:to_string, 1]} ==
               get_in(Value.mod_arg(Integer, [:to_string, 1]), [:value])

      assert %{
               __meta__: %{
                 errors: [type: [expected: "tuple(module(), list())", got: -42]]
               }
             } = Value.mod_arg(-42)
    end

    test "fun" do
      assert value =
               %{__meta__: %{defined?: true}, __context__: %{arity: 1}} =
               Value.fun(&Integer.to_string/1)

      assert "42" == value[:value].(42)

      assert %{
               __meta__: %{
                 errors: [type: [expected: "fun()", got: 42]]
               }
             } = put_in(Value.fun(), [:value], 42)
    end

    test "one_of" do
      assert value =
               %{__meta__: %{defined?: true}, __context__: %{allowed: [1, 2, 3]}} =
               Value.one_of(2, [1, 2, 3])

      assert 2 == value[:value]

      assert %{
               __meta__: %{
                 errors: [validation: [message: "Expected a value to be one of [1]", got: 42]]
               }
             } = put_in(Value.one_of([1]), [:value], 42)
    end

    test "list" do
      assert value =
               %{__meta__: %{defined?: true}} = Value.list([1, 2, 3], Tyyppi.parse(integer()))

      assert [1, 2, 3] == value[:value]

      assert %{
               __meta__: %{
                 errors: [
                   validation: [
                     message: "Expected all elements to be of type integer(). Failed: [:ok]",
                     got: [:ok, 42]
                   ]
                 ]
               }
             } = put_in(value, [:value], [:ok, 42])
    end

    test "formulae" do
      assert value = %{__meta__: %{defined?: true}} = Value.formulae(2, "value + 40")
      assert 42 == value[:value]

      assert value = %{__meta__: %{defined?: true}} = Value.formulae(2, {Integer, :to_string, []})
      assert "2" == value[:value]
    end

    test "struct" do
      assert value = %{__meta__: %{defined?: true}} = Value.struct(%Tyyppi.Example.Struct{})
      assert get_in(value, [:value, :baz]) == {:error, :reason}

      assert %{__meta__: %{defined?: false} = value} = Value.struct(DateTime.utc_now())

      assert get_in(value, ~w|errors validation message|a) =~
               ~r/The given struct does not respond to `validate\/1`/

      assert %{__meta__: %{defined?: false, errors: [type: [expected: "struct()", got: 42]]}} =
               put_in(Value.struct(), [:value], 42)
    end
  end

  describe "converters" do
    test "jason" do
      assert Jason.encode(Value.integer(42)) == {:ok, "42"}
      assert Jason.encode(Value.any(42)) == {:ok, "42"}
      assert Jason.encode(Value.atom(:ok)) == {:ok, ~S|"ok"|}
      assert Jason.encode(Value.string(42)) == {:ok, ~S|"42"|}
      assert Jason.encode(Value.boolean(true)) == {:ok, "true"}
      assert Jason.encode(Value.integer(42)) == {:ok, "42"}
      assert Jason.encode(Value.non_neg_integer(42)) == {:ok, "42"}
      assert Jason.encode(Value.pos_integer(42)) == {:ok, "42"}
      assert Jason.encode(Value.timeout(:infinity)) == {:ok, ~S|"infinity"|}

      assert Jason.encode(Value.pid(self())) ==
               {:ok, self() |> :erlang.pid_to_list() |> inspect()}

      # assert Jason.encode(Value.mfa(42)) == {:ok, "42"}
      # assert Jason.encode(Value.mod_arg(42)) == {:ok, "42"}
      # assert Jason.encode(Value.fun(42)) == {:ok, "42"}
      assert Jason.encode(Value.one_of(42, [42, :ok])) == {:ok, "42"}
      # assert Jason.encode(Value.formulae(42)) == {:ok, "42"}
      assert Jason.encode(Value.list([42], Tyyppi.parse(integer()))) == {:ok, "[42]"}
      # assert Jason.encode(Value.struct(42)) == {:ok, "42"}
    end
  end
end
