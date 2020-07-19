defmodule Test.Tyyppi.T do
  use ExUnit.Case

  require Tyyppi.T
  doctest Tyyppi.T

  setup_all do
    {:ok, pid} = Tyyppi.Stats.start_link()
    [stats: pid]
  end

  test "parse/1" do
    type = Tyyppi.T.parse(String.t())

    assert %Tyyppi.T{
             definition: {:type, _, :binary, []},
             module: String,
             name: :t,
             params: [],
             type: :type
           } = type
  end
end
