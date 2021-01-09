defmodule Test.Tyyppi.StructValue do
  use ExUnit.Case

  alias Tyyppi.{ExampleValue, Value}

  test "struct with all values" do
    ex = %ExampleValue{}

    assert %ExampleValue{bar: %Value{value: 5}} = put_in(ex, [:bar], 5)
    assert %ExampleValue{foo: %Value{value: :atom}} = put_in(ex, [:foo], 'atom')

    assert_raise BadStructError, "expected a struct named Tyyppi.ExampleValue, got: :baz", fn ->
      put_in(ex, [:baz], 5)
    end

    assert_raise ArgumentError, ~r"\Acould not put/update key :bar with value :ok", fn ->
      put_in(ex, [:bar], :ok)
    end
  end
end
