defmodule Test.Tyyppi.Stats do
  use ExUnit.Case

  alias Tyyppi.{Stats, T}

  doctest Tyyppi.Stats

  setup_all do
    {:error, {:already_started, pid}} = Stats.start_link(callback: &Test.Tyyppi.rehashed/2)
    [stats: pid]
  end

  test "returns types" do
    assert %T{module: String, name: :t, params: [], type: :type} = Stats.type({String, :t, 0})
  end

  test "calls rehashed callback" do
    ast =
      quote do
        use Boundary
        @type t :: any()
      end

    Tyyppi.Code.module!(T1, ast)

    assert %T{module: T1, name: :t, params: []} = Stats.type({T1, :t, 0})

    :code.purge(T1)
    :code.delete(T1)
  end
end
