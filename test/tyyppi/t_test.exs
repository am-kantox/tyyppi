defmodule Test.Tyyppi.T do
  use ExUnit.Case

  alias Tyyppi.{Stats, T}
  require T
  doctest T

  setup_all do
    ast =
      quote do
        use Boundary

        @type test_atom_1 :: atom()
        @type test_atom_2 :: true
        @type test_atom_3 :: false | nil

        @type test_remote :: GenServer.on_start()

        @type test_map_1 :: %{
                :foo => :ok | {:error, term},
                :on_start => test_remote()
              }
        @type test_map_2 :: %{required(atom()) => integer()}
        @type test_map_3 :: %{optional(atom()) => float()}

        @type test_list_1 :: []
        @type test_list_2 :: list()
        @type test_list_3 :: list(pos_integer())
        @type test_list_4 :: [neg_integer()]
        @type test_list_5 :: nonempty_list(number())
        @type test_list_6 :: maybe_improper_list(number(), pid())
        @type test_list_7 :: nonempty_improper_list(number(), pid())
        @type test_list_8 :: nonempty_maybe_improper_list(number(), pid())

        @type test_binary_1 :: <<>>
        @type test_binary_2 :: <<_::5>>
        @type test_binary_3 :: <<_::_*3>>
        @type test_binary_4 :: <<_::1, _::_*3>>

        @type test_fun_1 :: (() -> float())
        @type test_fun_2 :: (integer(), integer() -> integer())
        @type test_fun_3 :: (... -> integer())

        @type test_int_1 :: 1
        @type test_int_2 :: 1..10

        @type test_struct :: %DateTime{}

        def f1_1, do: 42.0
        def f1_2, do: 42
        def f1_3, do: :ok
        def f2_1(x, y), do: x * y
        def f2_2(x, y), do: x / y
        def f3_1(x), do: x * 42
        def f3_2(x), do: x * 42.0
      end

    case Code.ensure_compiled(Types) do
      {:module, Types} ->
        :ok

      _ ->
        {:module, mod, beam, _} = Module.create(Types, ast, Macro.Env.location(__ENV__))

        Mix.Project.app_path()
        |> Path.join("ebin")
        |> Path.join(to_string(mod) <> ".beam")
        |> File.write(beam)

        Stats.rehash!()
    end

    on_exit(fn ->
      :code.purge(Types)
      :code.delete(Types)
    end)

    {:ok, pid} = Stats.start_link()
    [stats: pid]
  end

  test "parse/1" do
    type = T.parse(String.t())

    assert %T{
             definition: {:type, _, :binary, []},
             module: String,
             name: :t,
             params: [],
             type: :type
           } = type
  end

  test "atom" do
    assert T.of?(atom(), :ok)
    assert T.of?(Types.test_atom_1(), :ok)
    refute T.of?(Types.test_atom_1(), "ok")

    assert T.of?(true, true)
    assert T.of?(Types.test_atom_2(), true)
    refute T.of?(Types.test_atom_2(), :ok)

    assert T.of?(Types.test_atom_3(), false)
    assert T.of?(Types.test_atom_3(), nil)
    refute T.of?(Types.test_atom_3(), true)
    refute T.of?(Types.test_atom_3(), :ok)
  end

  test "pid, reference" do
    assert T.of?(pid(), self())
    assert T.of?(reference, make_ref())
    refute T.of?(ref, make_ref())
  end

  test "remote" do
    assert T.of?(Types.test_remote(), {:ok, self()})
    assert T.of?(Types.test_remote(), {:error, {:already_started, self()}})
    refute T.of?(Types.test_remote(), :ok)
  end

  test "map" do
    assert T.of?(Types.test_map_1(), %{foo: :ok, on_start: {:ok, self()}})
    refute T.of?(Types.test_map_1(), %{foo: :ok})
    refute T.of?(Types.test_map_1(), :ok)

    assert T.of?(Types.test_map_2(), %{foo: 42})
    refute T.of?(Types.test_map_2(), %{})
    refute T.of?(Types.test_map_2(), %{foo: :ok})
    refute T.of?(Types.test_map_2(), %{"foo" => :ok})
    refute T.of?(Types.test_map_2(), :ok)

    assert T.of?(Types.test_map_3(), %{foo: 42.0})
    assert T.of?(Types.test_map_3(), %{})
    refute T.of?(Types.test_map_3(), %{foo: 42})
    refute T.of?(Types.test_map_3(), %{"foo" => :ok})
    refute T.of?(Types.test_map_3(), :ok)
  end

  test "list" do
    assert T.of?(Types.test_list_1(), [])
    refute T.of?(Types.test_list_1(), [:foo])
    refute T.of?(Types.test_list_1(), [:foo | :bar])

    assert T.of?(Types.test_list_2(), [])
    assert T.of?(Types.test_list_2(), [:foo])
    refute T.of?(Types.test_list_2(), [:foo | :bar])

    assert T.of?(Types.test_list_3(), [])
    assert T.of?(Types.test_list_3(), [42])
    refute T.of?(Types.test_list_3(), [:foo])
    refute T.of?(Types.test_list_3(), [:foo | :bar])

    assert T.of?(Types.test_list_4(), [])
    assert T.of?(Types.test_list_4(), [-42])
    refute T.of?(Types.test_list_4(), [-42.0])
    refute T.of?(Types.test_list_4(), [42])
    refute T.of?(Types.test_list_4(), [:foo])
    refute T.of?(Types.test_list_4(), [:foo | :bar])

    assert T.of?(Types.test_list_5(), [42])
    assert T.of?(Types.test_list_5(), [42.0])
    refute T.of?(Types.test_list_5(), [])
    refute T.of?(Types.test_list_5(), [:foo])
    refute T.of?(Types.test_list_5(), [:foo | :bar])

    assert T.of?(Types.test_list_6(), [42])
    assert T.of?(Types.test_list_6(), [42.0])
    assert T.of?(Types.test_list_6(), [])
    assert T.of?(Types.test_list_6(), [42 | self()])
    refute T.of?(Types.test_list_6(), [:foo])
    refute T.of?(Types.test_list_6(), [:foo | :bar])

    refute T.of?(Types.test_list_7(), [42])
    refute T.of?(Types.test_list_7(), [42.0])
    refute T.of?(Types.test_list_7(), [])
    refute T.of?(Types.test_list_7(), [:foo])
    assert T.of?(Types.test_list_7(), [:foo | self()])
    refute T.of?(Types.test_list_7(), [:foo | :bar])

    assert T.of?(Types.test_list_8(), [42])
    assert T.of?(Types.test_list_8(), [42.0])
    assert T.of?(Types.test_list_7(), [42 | self()])
    refute T.of?(Types.test_list_8(), [])
    refute T.of?(Types.test_list_8(), [:foo])
    refute T.of?(Types.test_list_8(), [:foo | :bar])
  end

  test "binary" do
    assert T.of?(Types.test_binary_1(), <<>>)
    assert T.of?(Types.test_binary_1(), "")
    refute T.of?(Types.test_binary_1(), "foo")
    refute T.of?(Types.test_binary_1(), :foo)

    refute T.of?(Types.test_binary_2(), <<>>)
    assert T.of?(Types.test_binary_2(), "12345")
    refute T.of?(Types.test_binary_2(), "1234")
    refute T.of?(Types.test_binary_2(), "123456")
    refute T.of?(Types.test_binary_2(), :foo)

    assert T.of?(Types.test_binary_3(), <<>>)
    assert T.of?(Types.test_binary_3(), <<4::3>>)
    assert T.of?(Types.test_binary_3(), <<4::3, 5::3>>)
    assert T.of?(Types.test_binary_3(), <<4::6>>)
    refute T.of?(Types.test_binary_3(), <<4::4>>)
    refute T.of?(Types.test_binary_3(), :foo)

    refute T.of?(Types.test_binary_4(), <<>>)
    assert T.of?(Types.test_binary_4(), <<4::3>>)
    assert T.of?(Types.test_binary_4(), <<1::1, 1::1, 1::1>>)
    refute T.of?(Types.test_binary_4(), <<4::6>>)
    refute T.of?(Types.test_binary_4(), :foo)
  end

  test "integers / ranges" do
    assert T.of?(Types.test_int_1(), 1)
    refute T.of?(Types.test_int_1(), 2)
    refute T.of?(Types.test_int_1(), :ok)

    assert T.of?(Types.test_int_2(), 1)
    assert T.of?(Types.test_int_2(), 2)
    refute T.of?(Types.test_int_2(), 0)
    refute T.of?(Types.test_int_2(), :ok)
  end

  test "struct" do
    assert T.of?(Types.test_struct(), DateTime.utc_now())
    refute T.of?(Types.test_struct(), 42)
  end

  test "fun" do
    assert T.of?(Types.test_fun_1(), fn -> 42.0 end)
    refute T.of?(Types.test_fun_1(), fn x -> x end)
    assert T.of?(Types.test_fun_2(), fn x, y -> x * y end)
    refute T.of?(Types.test_fun_2(), fn x -> x end)
    assert T.of?(Types.test_fun_3(), fn -> 42.0 end)
    assert T.of?(Types.test_fun_3(), fn x -> x * 42.0 end)
    assert T.of?(Types.test_fun_3(), fn x, y -> x * y end)

    assert {:ok, 42.0} = T.apply(Types.test_fun_1(), &Types.f1_1/0, [])
    assert {:error, {:result, 42}} = T.apply(Types.test_fun_1(), &Types.f1_2/0, [])
    assert {:error, {:result, :ok}} = T.apply(Types.test_fun_1(), &Types.f1_3/0, [])
    assert {:ok, 4} = T.apply(Types.test_fun_2(), &Types.f2_1/2, [2, 2])
    assert {:error, {:arity, 1}} = T.apply(Types.test_fun_2(), &Types.f2_1/2, [42])

    assert {:error, {:args, [42, 42.0]}} = T.apply(Types.test_fun_2(), &Types.f2_1/2, [42, 42.0])

    assert {:error, {:result, 1.0}} = T.apply(Types.test_fun_2(), &Types.f2_2/2, [42, 42])

    assert {:ok, 84} = T.apply(Types.test_fun_3(), &Types.f3_1/1, [2])
    assert {:error, {:result, 84.0}} = T.apply(Types.test_fun_3(), &Types.f3_1/1, [2.0])
    assert {:error, {:arity, 0}} = T.apply(Types.test_fun_3(), &Types.f3_1/1, [])

    assert_raise ArithmeticError, fn ->
      T.apply(Types.test_fun_3(), &Types.f3_1/1, [:ok])
    end

    assert {:error, {:result, 84.0}} = T.apply(Types.test_fun_3(), &Types.f3_2/1, [2])

    assert {:ok, "foo"} = T.apply(&Atom.to_string/1, [:foo])
    assert {:error, {:args, ["foo"]}} = T.apply(&Atom.to_string/1, ["foo"])
  end
end
