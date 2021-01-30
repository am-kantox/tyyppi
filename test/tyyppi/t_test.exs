defmodule Test.Tyyppi.T do
  use ExUnit.Case

  alias Tyyppi.Stats
  doctest Tyyppi.T

  require Tyyppi
  alias Tyyppi.Example.Types

  setup_all do
    {:error, {:already_started, pid}} = Stats.start_link()
    Stats.rehash!()
    [stats: pid]
  end

  test "parse/1" do
    type = Tyyppi.parse(String.t())

    assert %Tyyppi.T{
             definition: {:type, _, :binary, []},
             module: String,
             name: :t,
             params: [],
             type: :type
           } = type
  end

  test "atom" do
    assert Tyyppi.of?(atom(), :ok)
    assert Tyyppi.of?(Types.test_atom_1(), :ok)
    refute Tyyppi.of?(Types.test_atom_1(), "ok")

    assert Tyyppi.of?(true, true)
    assert Tyyppi.of?(Types.test_atom_2(), true)
    refute Tyyppi.of?(Types.test_atom_2(), :ok)

    assert Tyyppi.of?(Types.test_atom_3(), false)
    assert Tyyppi.of?(Types.test_atom_3(), nil)
    refute Tyyppi.of?(Types.test_atom_3(), true)
    refute Tyyppi.of?(Types.test_atom_3(), :ok)
  end

  test "pid, reference" do
    assert Tyyppi.of?(pid(), self())
    assert Tyyppi.of?(reference, make_ref())
    refute Tyyppi.of?(ref, make_ref())
  end

  test "unions, tuples" do
    assert Tyyppi.of?({:ok, pid()} | :error, {:ok, self()})
    assert Tyyppi.of?({:ok, pid()} | :error, :error)
    refute Tyyppi.of?({:ok, pid()} | :error, :ok)

    assert Tyyppi.of?({:ok, map()} | keyword, {:ok, %{}})
    assert Tyyppi.of?({:ok, map()} | keyword, [{:ok, %{}}])
    assert Tyyppi.of?({:ok, map()} | keyword, ok: %{})
    refute Tyyppi.of?({:ok, map()} | keyword, %{})
  end

  test "remote" do
    assert Tyyppi.of?(Types.test_remote(), {:ok, self()})
    assert Tyyppi.of?(Types.test_remote(), {:error, {:already_started, self()}})
    refute Tyyppi.of?(Types.test_remote(), :ok)
  end

  test "map" do
    assert Tyyppi.of?(Types.test_map_1(), %{foo: :ok, on_start: {:ok, self()}})
    refute Tyyppi.of?(Types.test_map_1(), %{foo: :ok})
    refute Tyyppi.of?(Types.test_map_1(), :ok)

    assert Tyyppi.of?(Types.test_map_2(), %{foo: 42})
    refute Tyyppi.of?(Types.test_map_2(), %{})
    refute Tyyppi.of?(Types.test_map_2(), %{foo: :ok})
    refute Tyyppi.of?(Types.test_map_2(), %{"foo" => :ok})
    refute Tyyppi.of?(Types.test_map_2(), :ok)

    assert Tyyppi.of?(Types.test_map_3(), %{foo: 42.0})
    assert Tyyppi.of?(Types.test_map_3(), %{})
    refute Tyyppi.of?(Types.test_map_3(), %{foo: 42})
    refute Tyyppi.of?(Types.test_map_3(), %{"foo" => :ok})
    refute Tyyppi.of?(Types.test_map_3(), :ok)
  end

  test "list" do
    assert Tyyppi.of?(Types.test_list_1(), [])
    refute Tyyppi.of?(Types.test_list_1(), [:foo])
    refute Tyyppi.of?(Types.test_list_1(), [:foo | :bar])

    assert Tyyppi.of?(Types.test_list_2(), [])
    assert Tyyppi.of?(Types.test_list_2(), [:foo])
    refute Tyyppi.of?(Types.test_list_2(), [:foo | :bar])

    assert Tyyppi.of?(Types.test_list_3(), [])
    assert Tyyppi.of?(Types.test_list_3(), [42])
    refute Tyyppi.of?(Types.test_list_3(), [:foo])
    refute Tyyppi.of?(Types.test_list_3(), [:foo | :bar])

    assert Tyyppi.of?(Types.test_list_4(), [])
    assert Tyyppi.of?(Types.test_list_4(), [-42])
    refute Tyyppi.of?(Types.test_list_4(), [-42.0])
    refute Tyyppi.of?(Types.test_list_4(), [42])
    refute Tyyppi.of?(Types.test_list_4(), [:foo])
    refute Tyyppi.of?(Types.test_list_4(), [:foo | :bar])

    assert Tyyppi.of?(Types.test_list_5(), [42])
    assert Tyyppi.of?(Types.test_list_5(), [42.0])
    refute Tyyppi.of?(Types.test_list_5(), [])
    refute Tyyppi.of?(Types.test_list_5(), [:foo])
    refute Tyyppi.of?(Types.test_list_5(), [:foo | :bar])

    assert Tyyppi.of?(Types.test_list_6(), [42])
    assert Tyyppi.of?(Types.test_list_6(), [42.0])
    assert Tyyppi.of?(Types.test_list_6(), [])
    assert Tyyppi.of?(Types.test_list_6(), [42 | self()])
    refute Tyyppi.of?(Types.test_list_6(), [:foo])
    refute Tyyppi.of?(Types.test_list_6(), [:foo | :bar])

    refute Tyyppi.of?(Types.test_list_7(), [42])
    refute Tyyppi.of?(Types.test_list_7(), [42.0])
    refute Tyyppi.of?(Types.test_list_7(), [])
    refute Tyyppi.of?(Types.test_list_7(), [:foo])
    assert Tyyppi.of?(Types.test_list_7(), [:foo | self()])
    refute Tyyppi.of?(Types.test_list_7(), [:foo | :bar])

    assert Tyyppi.of?(Types.test_list_8(), [42])
    assert Tyyppi.of?(Types.test_list_8(), [42.0])
    assert Tyyppi.of?(Types.test_list_7(), [42 | self()])
    refute Tyyppi.of?(Types.test_list_8(), [])
    refute Tyyppi.of?(Types.test_list_8(), [:foo])
    refute Tyyppi.of?(Types.test_list_8(), [:foo | :bar])
  end

  test "binary" do
    assert Tyyppi.of?(Types.test_binary_1(), <<>>)
    assert Tyyppi.of?(Types.test_binary_1(), "")
    refute Tyyppi.of?(Types.test_binary_1(), "foo")
    refute Tyyppi.of?(Types.test_binary_1(), :foo)

    refute Tyyppi.of?(Types.test_binary_2(), <<>>)
    assert Tyyppi.of?(Types.test_binary_2(), "12345")
    refute Tyyppi.of?(Types.test_binary_2(), "1234")
    refute Tyyppi.of?(Types.test_binary_2(), "123456")
    refute Tyyppi.of?(Types.test_binary_2(), :foo)

    assert Tyyppi.of?(Types.test_binary_3(), <<>>)
    assert Tyyppi.of?(Types.test_binary_3(), <<4::3>>)
    assert Tyyppi.of?(Types.test_binary_3(), <<4::3, 5::3>>)
    assert Tyyppi.of?(Types.test_binary_3(), <<4::6>>)
    refute Tyyppi.of?(Types.test_binary_3(), <<4::4>>)
    refute Tyyppi.of?(Types.test_binary_3(), :foo)

    refute Tyyppi.of?(Types.test_binary_4(), <<>>)
    assert Tyyppi.of?(Types.test_binary_4(), <<4::3>>)
    assert Tyyppi.of?(Types.test_binary_4(), <<1::1, 1::1, 1::1>>)
    refute Tyyppi.of?(Types.test_binary_4(), <<4::6>>)
    refute Tyyppi.of?(Types.test_binary_4(), :foo)
  end

  test "integers / ranges" do
    assert Tyyppi.of?(Types.test_int_1(), 1)
    refute Tyyppi.of?(Types.test_int_1(), 2)
    refute Tyyppi.of?(Types.test_int_1(), :ok)

    assert Tyyppi.of?(Types.test_int_2(), 1)
    assert Tyyppi.of?(Types.test_int_2(), 2)
    refute Tyyppi.of?(Types.test_int_2(), 0)
    refute Tyyppi.of?(Types.test_int_2(), :ok)
  end

  test "struct" do
    assert Tyyppi.of?(Types.test_struct(), DateTime.utc_now())
    refute Tyyppi.of?(Types.test_struct(), 42)
  end

  test "fun" do
    assert Tyyppi.of?((atom() -> binary()), fn a -> to_string(a) end)
    assert Tyyppi.of?((atom() -> binary()), &Atom.to_string/1)
    refute Tyyppi.of?((atom() -> binary()), fn -> "ok" end)

    assert Tyyppi.of?(Types.test_fun_1(), fn -> 42.0 end)
    refute Tyyppi.of?(Types.test_fun_1(), fn x -> x end)
    assert Tyyppi.of?(Types.test_fun_2(), fn x, y -> x * y end)
    refute Tyyppi.of?(Types.test_fun_2(), fn x -> x end)
    assert Tyyppi.of?(Types.test_fun_3(), fn -> 42.0 end)
    assert Tyyppi.of?(Types.test_fun_3(), fn x -> x * 42.0 end)
    assert Tyyppi.of?(Types.test_fun_3(), fn x, y -> x * y end)
  end

  test "Tyyppi.apply" do
    assert {:ok, 42.0} = Tyyppi.apply(Types.test_fun_1(), &Types.f1_1/0, [])
    assert {:error, {:result, 42}} = Tyyppi.apply(Types.test_fun_1(), &Types.f1_2/0, [])
    assert {:error, {:result, :ok}} = Tyyppi.apply(Types.test_fun_1(), &Types.f1_3/0, [])
    assert {:ok, 4} = Tyyppi.apply(Types.test_fun_2(), &Types.f2_1/2, [2, 2])
    assert {:error, {:arity, 1}} = Tyyppi.apply(Types.test_fun_2(), &Types.f2_1/2, [42])

    assert {:error, {:args, [42, 42.0]}} =
             Tyyppi.apply(Types.test_fun_2(), &Types.f2_1/2, [42, 42.0])

    assert {:error, {:result, 1.0}} = Tyyppi.apply(Types.test_fun_2(), &Types.f2_2/2, [42, 42])

    assert {:ok, 84} = Tyyppi.apply(Types.test_fun_3(), &Types.f3_1/1, [2])
    assert {:error, {:result, 84.0}} = Tyyppi.apply(Types.test_fun_3(), &Types.f3_1/1, [2.0])
    assert {:error, {:arity, 0}} = Tyyppi.apply(Types.test_fun_3(), &Types.f3_1/1, [])

    assert_raise ArithmeticError, fn ->
      Tyyppi.apply(Types.test_fun_3(), &Types.f3_1/1, [:ok])
    end

    assert {:error, {:result, 84.0}} = Tyyppi.apply(Types.test_fun_3(), &Types.f3_2/1, [2])

    assert {:ok, "foo"} = Tyyppi.apply(&Atom.to_string/1, [:foo])
    assert {:ok, "42"} = Tyyppi.apply(&Integer.to_string/1, [42])
    assert {:error, {:args, ["foo"]}} = Tyyppi.apply(&Atom.to_string/1, ["foo"])
    assert {:error, {:args, ["foo"]}} = Tyyppi.apply(&Integer.to_string/1, ["foo"])
  end

  test "String.Char" do
    assert to_string(Tyyppi.parse(atom)) == "atom()"
    assert to_string(Tyyppi.parse(GenServer.on_start())) == "GenServer.on_start()"
  end
end
