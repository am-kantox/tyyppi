defmodule Test.Tyyppi.StructValue do
  use ExUnit.Case

  alias Tyyppi.Example.Value, as: ExampleValue
  alias Tyyppi.{Struct, Value}

  test "struct with all values" do
    ex = %ExampleValue{}

    assert %ExampleValue{bar: %Value{value: 5}} = put_in(ex, [:bar], 5)
    assert %ExampleValue{foo: %Value{value: :atom}} = put_in(ex, [:foo], 'atom')
    assert %ExampleValue{foo: %Value{value: :atom}} = Struct.update!(ex, :foo, fn _ -> 'atom' end)

    assert {:error,
            [foo: [coercion: [message: "Expected atom(), charlist() or binary()", got: 5]]]} =
             Struct.update(ex, :foo, fn _ -> 5 end)

    v_101 = Value.integer(101)

    assert {:error,
            [
              bar: [
                validation: [
                  message: "Expected a value to be less than 100",
                  got: 101,
                  cast: ^v_101
                ]
              ]
            ]} = Struct.update(ex, :bar, fn _ -> 101 end)

    assert_raise BadStructError,
                 "expected a struct named Tyyppi.Example.Value, got: :baz",
                 fn ->
                   put_in(ex, [:baz], 5)
                 end

    assert_raise ArgumentError, ~r"\Acould not put/update key :bar with value :ok", fn ->
      put_in(ex, [:bar], :ok)
    end
  end
end
