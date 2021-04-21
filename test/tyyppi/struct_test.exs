defmodule Test.Tyyppi.Struct do
  use ExUnit.Case

  alias Tyyppi.{Stats, T}

  doctest Tyyppi.Struct

  setup_all do
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

    {:error, {:already_started, pid}} = Stats.start_link()
    Stats.rehash!()
    [stats: pid]
  end

  test "reverse quoted types in struct" do
    types = Tyyppi.Example.Struct.types()
    {foo, bar, baz} = {types[:foo], types[:bar], types[:baz]}
    baz_quoted = baz.quoted

    assert ^foo = T.parse_quoted(types[:foo].quoted)
    assert ^bar = T.parse_quoted(types[:bar].quoted)
    assert ^baz_quoted = T.parse_quoted(types[:baz].quoted).quoted
  end

  test "flatten/1" do
    v = %Tyyppi.Example.Value{}
    date = v.baz.value

    assert Tyyppi.Struct.flatten(v) == %{"bar" => 42, "baz" => date, "foo" => nil, "str" => nil}
    assert Tyyppi.Struct.flatten(v, squeeze: true) == %{"bar" => 42, "baz" => date}

    s = %Tyyppi.Example.NestedValue{}
    date_time = s.date_time.value

    assert Tyyppi.Struct.flatten(s) == %{
             "date_time" => date_time,
             "string" => nil,
             "struct_bar" => 42,
             "struct_baz" => date,
             "struct_foo" => nil,
             "struct_str" => nil
           }

    assert Tyyppi.Struct.flatten(s, squeeze: true) == %{
             "date_time" => date_time,
             "struct_bar" => 42,
             "struct_baz" => date
           }
  end
end
