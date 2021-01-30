defmodule Test.Tyyppi.Generation do
  use ExUnit.Case

  alias Tyyppi.Example.Nested

  test "generates valid values" do
    assert [:ok] =
             %Nested{}
             |> Nested.generation()
             |> Stream.map(&Nested.validate/1)
             |> Enum.take(10)
             |> Keyword.keys()
             |> Enum.uniq()
  end
end
