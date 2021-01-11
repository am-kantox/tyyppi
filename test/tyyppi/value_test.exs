defmodule Test.Tyyppi.Value do
  use ExUnit.Case

  require Tyyppi
  alias Tyyppi.Value

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

  test "timeout" do
    assert 42 == get_in(Value.timeout(42), [:value])
    assert 42 == get_in(Value.timeout("42"), [:value])
    assert 42 == get_in(Value.timeout(42.1), [:value])
    assert 0 == get_in(Value.timeout(0), [:value])
    assert :infinity == get_in(Value.timeout(:infinity), [:value])

    assert %{__meta__: %{errors: [type: [expected: "timeout()", got: -42]]}} = Value.timeout(-42)

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
                 coercion: [message: "Expected a value that can be converted to pid()", got: :ok]
               ]
             }
           } = Value.pid(:ok)
  end

  test "mfa" do
    assert {Integer, :to_string, 2} == get_in(Value.mfa({Integer, :to_string, 2}), [:value])
    assert {Integer, :to_string, 1} == get_in(Value.mfa(Integer, :to_string, 1), [:value])

    assert %{
             __meta__: %{
               errors: [type: [expected: "tuple(module(), atom(), non_neg_integer())", got: -42]]
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
           } = Value.mfa({Integer, :to_string, 0})
  end

  test "mod_arg" do
    assert {Integer, []} == get_in(Value.mod_arg({Integer, []}), [:value])
    assert {Integer, [:to_string, 1]} == get_in(Value.mod_arg(Integer, [:to_string, 1]), [:value])

    assert %{
             __meta__: %{
               errors: [type: [expected: "tuple(module(), list())", got: -42]]
             }
           } = Value.mod_arg(-42)
  end
end
