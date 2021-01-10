defmodule Test.Tyyppi.Value do
  use ExUnit.Case

  alias Tyyppi.Value

  test "any" do
    assert :ok = get_in(Value.any(:ok), [:value])
    assert "ok" = get_in(Value.any("ok"), [:value])
    assert 'ok' = get_in(Value.any('ok'), [:value])
  end

  test "atom" do
    assert :ok = get_in(Value.atom(:ok), [:value])
    assert :ok = get_in(Value.atom("ok"), [:value])
    assert :ok = get_in(Value.atom('ok'), [:value])

    assert %{__meta__: %{errors: [{:coercion, _error}]}} = Value.integer("42.1")
  end

  test "string" do
    assert "ok" = get_in(Value.string(:ok), [:value])
    assert "ok" = get_in(Value.string("ok"), [:value])
    assert "ok" = get_in(Value.string('ok'), [:value])

    assert %{__meta__: %{errors: [{:coercion, _error}]}} = Value.string(self())
  end

  test "boolean" do
    assert get_in(Value.boolean(:ok), [:value])
    assert get_in(Value.boolean(true), [:value])
    refute get_in(Value.boolean(false), [:value])
    refute get_in(Value.boolean(nil), [:value])
  end

  test "integer" do
    assert 42 = get_in(Value.integer(42), [:value])
    assert 42 = get_in(Value.integer("42"), [:value])
    assert 42 = get_in(Value.integer(42.1), [:value])

    assert %{__meta__: %{errors: [{:coercion, _error}]}} = Value.integer("42.1")
  end

  test "non_neg_integer / pos_integer" do
    assert 42 = get_in(Value.non_neg_integer(42), [:value])
    assert 42 = get_in(Value.non_neg_integer("42"), [:value])
    assert 42 = get_in(Value.non_neg_integer(42.1), [:value])
    assert 0 = get_in(Value.non_neg_integer(0), [:value])

    assert %{__meta__: %{errors: [type: [expected: "non_neg_integer()", got: -42]]}} =
             Value.non_neg_integer(-42)

    assert %{__meta__: %{errors: [type: [expected: "pos_integer()", got: 0]]}} =
             Value.pos_integer(0)
  end
end
