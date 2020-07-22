defmodule Test.Tyyppi.Struct do
  use ExUnit.Case

  alias Tyyppi.{Stats, T}

  doctest Tyyppi.Struct

  setup_all do
    {:ok, pid} = Stats.start_link()

    ast =
      quote do
        use Boundary

        require Tyyppi.Struct
        @type my_type :: :ok | {:error, term()}
        Tyyppi.Struct.defstruct(foo: atom(), bar: GenServer.on_start(), baz: my_type())
      end

    Tyyppi.Code.module!(TypedStruct, ast)

    on_exit(fn ->
      :code.purge(TypedStruct)
      :code.delete(TypedStruct)
    end)

    [stats: pid]
  end

  test "reverse quoted types in struct" do
    types = TypedStruct.types()
    {foo, bar, baz} = {types[:foo], types[:bar], types[:baz]}
    baz_quoted = baz.quoted

    assert ^foo = T.parse_quoted(types[:foo].quoted)
    assert ^bar = T.parse_quoted(types[:bar].quoted)
    assert ^baz_quoted = T.parse_quoted(types[:baz].quoted).quoted
  end
end
