defmodule Test.Tyyppi.Value do
  use ExUnit.Case

  alias Tyyppi.{Value}

  setup_all do
    _ast =
      quote do
      end

    on_exit(fn ->
      nil
    end)
  end

  test "atom" do
    assert :ok = get_in(Value.atom(:ok), [:value])
    assert :ok = get_in(Value.atom("ok"), [:value])
    assert :ok = get_in(Value.atom('ok'), [:value])

    assert %{__meta__: %{errors: [{:coercion, _error}]}} = Value.integer("42.1")
  end

  test "integer" do
    assert 42 = get_in(Value.integer(42), [:value])
    assert 42 = get_in(Value.integer("42"), [:value])
    assert 42 = get_in(Value.integer(42.1), [:value])

    assert %{__meta__: %{errors: [{:coercion, _error}]}} = Value.integer("42.1")
  end
end
