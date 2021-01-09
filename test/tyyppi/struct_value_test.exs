defmodule Test.Tyyppi.StructValue do
  use ExUnit.Case

  alias Tyyppi.{ExampleValue, Value}

  test "struct with all values" do
    ex = %ExampleValue{}

    assert %ExampleValue{bar: %Value{value: 5}} = put_in(ex, [:bar], 5)

    # assert %ExampleValue{bar: %Value{__meta__: %{errors: [_ | _]}, value: 42}} =
    #          put_in(ex, [:bar], :ok)
    assert_raise ArgumentError, ~r"\Acould not put/update key :bar with value :ok", fn ->
      put_in(ex, [:bar], :ok)
    end
  end
end
