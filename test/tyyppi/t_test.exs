defmodule Test.Tyyppi.T do
  use ExUnit.Case

  require Tyyppi.T
  doctest Tyyppi.T

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

        with path when not is_nil(path) <- System.tmp_dir() do
          Mix.Project.app_path()
          |> Path.join("ebin")
          |> Path.join(to_string(mod) <> ".beam")
          |> File.write(beam)
        end

        Tyyppi.Stats.rehash!()
    end

    on_exit(fn ->
      :code.purge(Types)
      :code.delete(Types)
    end)

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

  test "atom" do
    assert Tyyppi.T.of?(Types.test_atom_1(), :ok)
    refute Tyyppi.T.of?(Types.test_atom_1(), "ok")

    assert Tyyppi.T.of?(Types.test_atom_2(), true)
    refute Tyyppi.T.of?(Types.test_atom_2(), :ok)

    assert Tyyppi.T.of?(Types.test_atom_3(), false)
    assert Tyyppi.T.of?(Types.test_atom_3(), nil)
    refute Tyyppi.T.of?(Types.test_atom_3(), true)
    refute Tyyppi.T.of?(Types.test_atom_3(), :ok)
  end

  test "remote" do
    assert Tyyppi.T.of?(Types.test_remote(), {:ok, self()})
    assert Tyyppi.T.of?(Types.test_remote(), {:error, {:already_started, self()}})
    refute Tyyppi.T.of?(Types.test_remote(), :ok)
  end

  test "map" do
    assert Tyyppi.T.of?(Types.test_map_1(), %{foo: :ok, on_start: {:ok, self()}})
    refute Tyyppi.T.of?(Types.test_map_1(), %{foo: :ok})
    refute Tyyppi.T.of?(Types.test_map_1(), :ok)

    assert Tyyppi.T.of?(Types.test_map_2(), %{foo: 42})
    refute Tyyppi.T.of?(Types.test_map_2(), %{})
    refute Tyyppi.T.of?(Types.test_map_2(), %{foo: :ok})
    refute Tyyppi.T.of?(Types.test_map_2(), %{"foo" => :ok})
    refute Tyyppi.T.of?(Types.test_map_2(), :ok)

    assert Tyyppi.T.of?(Types.test_map_3(), %{foo: 42.0})
    assert Tyyppi.T.of?(Types.test_map_3(), %{})
    refute Tyyppi.T.of?(Types.test_map_3(), %{foo: 42})
    refute Tyyppi.T.of?(Types.test_map_3(), %{"foo" => :ok})
    refute Tyyppi.T.of?(Types.test_map_3(), :ok)
  end

  test "list" do
    assert Tyyppi.T.of?(Types.test_list_1(), [])
    refute Tyyppi.T.of?(Types.test_list_1(), [:foo])
    refute Tyyppi.T.of?(Types.test_list_1(), [:foo | :bar])

    assert Tyyppi.T.of?(Types.test_list_2(), [])
    assert Tyyppi.T.of?(Types.test_list_2(), [:foo])
    refute Tyyppi.T.of?(Types.test_list_2(), [:foo | :bar])

    assert Tyyppi.T.of?(Types.test_list_3(), [])
    assert Tyyppi.T.of?(Types.test_list_3(), [42])
    refute Tyyppi.T.of?(Types.test_list_3(), [:foo])
    refute Tyyppi.T.of?(Types.test_list_3(), [:foo | :bar])

    assert Tyyppi.T.of?(Types.test_list_4(), [])
    assert Tyyppi.T.of?(Types.test_list_4(), [-42])
    refute Tyyppi.T.of?(Types.test_list_4(), [-42.0])
    refute Tyyppi.T.of?(Types.test_list_4(), [42])
    refute Tyyppi.T.of?(Types.test_list_4(), [:foo])
    refute Tyyppi.T.of?(Types.test_list_4(), [:foo | :bar])

    assert Tyyppi.T.of?(Types.test_list_5(), [42])
    assert Tyyppi.T.of?(Types.test_list_5(), [42.0])
    refute Tyyppi.T.of?(Types.test_list_5(), [])
    refute Tyyppi.T.of?(Types.test_list_5(), [:foo])
    refute Tyyppi.T.of?(Types.test_list_5(), [:foo | :bar])

    assert Tyyppi.T.of?(Types.test_list_6(), [42])
    assert Tyyppi.T.of?(Types.test_list_6(), [42.0])
    assert Tyyppi.T.of?(Types.test_list_6(), [])
    assert Tyyppi.T.of?(Types.test_list_6(), [42 | self()])
    refute Tyyppi.T.of?(Types.test_list_6(), [:foo])
    refute Tyyppi.T.of?(Types.test_list_6(), [:foo | :bar])

    refute Tyyppi.T.of?(Types.test_list_7(), [42])
    refute Tyyppi.T.of?(Types.test_list_7(), [42.0])
    refute Tyyppi.T.of?(Types.test_list_7(), [])
    refute Tyyppi.T.of?(Types.test_list_7(), [:foo])
    assert Tyyppi.T.of?(Types.test_list_7(), [:foo | self()])
    refute Tyyppi.T.of?(Types.test_list_7(), [:foo | :bar])

    assert Tyyppi.T.of?(Types.test_list_8(), [42])
    assert Tyyppi.T.of?(Types.test_list_8(), [42.0])
    assert Tyyppi.T.of?(Types.test_list_7(), [42 | self()])
    refute Tyyppi.T.of?(Types.test_list_8(), [])
    refute Tyyppi.T.of?(Types.test_list_8(), [:foo])
    refute Tyyppi.T.of?(Types.test_list_8(), [:foo | :bar])
  end

  test "binary" do
    assert Tyyppi.T.of?(Types.test_binary_1(), <<>>)
    assert Tyyppi.T.of?(Types.test_binary_1(), "")
    refute Tyyppi.T.of?(Types.test_binary_1(), "foo")
    refute Tyyppi.T.of?(Types.test_binary_1(), :foo)

    refute Tyyppi.T.of?(Types.test_binary_2(), <<>>)
    assert Tyyppi.T.of?(Types.test_binary_2(), "12345")
    refute Tyyppi.T.of?(Types.test_binary_2(), "1234")
    refute Tyyppi.T.of?(Types.test_binary_2(), "123456")
    refute Tyyppi.T.of?(Types.test_binary_2(), :foo)

    assert Tyyppi.T.of?(Types.test_binary_3(), <<>>)
    assert Tyyppi.T.of?(Types.test_binary_3(), <<4::3>>)
    assert Tyyppi.T.of?(Types.test_binary_3(), <<4::3, 5::3>>)
    assert Tyyppi.T.of?(Types.test_binary_3(), <<4::6>>)
    refute Tyyppi.T.of?(Types.test_binary_3(), <<4::4>>)
    refute Tyyppi.T.of?(Types.test_binary_3(), :foo)

    refute Tyyppi.T.of?(Types.test_binary_4(), <<>>)
    assert Tyyppi.T.of?(Types.test_binary_4(), <<4::3>>)
    assert Tyyppi.T.of?(Types.test_binary_4(), <<1::1, 1::1, 1::1>>)
    refute Tyyppi.T.of?(Types.test_binary_4(), <<4::6>>)
    refute Tyyppi.T.of?(Types.test_binary_4(), :foo)
  end

  test "integers / ranges" do
    assert Tyyppi.T.of?(Types.test_int_1(), 1)
    refute Tyyppi.T.of?(Types.test_int_1(), 2)
    refute Tyyppi.T.of?(Types.test_int_1(), :ok)

    assert Tyyppi.T.of?(Types.test_int_2(), 1)
    assert Tyyppi.T.of?(Types.test_int_2(), 2)
    refute Tyyppi.T.of?(Types.test_int_2(), 0)
    refute Tyyppi.T.of?(Types.test_int_2(), :ok)
  end

  test "struct" do
    assert Tyyppi.T.of?(Types.test_struct(), DateTime.utc_now())
    refute Tyyppi.T.of?(Types.test_struct(), 42)
  end

  test "fun" do
    assert Tyyppi.T.of?(Types.test_fun_1(), fn -> 42.0 end)
    refute Tyyppi.T.of?(Types.test_fun_1(), fn x -> x end)
    assert Tyyppi.T.of?(Types.test_fun_2(), fn x, y -> x * y end)
    refute Tyyppi.T.of?(Types.test_fun_2(), fn x -> x end)
    assert Tyyppi.T.of?(Types.test_fun_3(), fn -> 42.0 end)
    assert Tyyppi.T.of?(Types.test_fun_3(), fn x -> x * 42.0 end)
    assert Tyyppi.T.of?(Types.test_fun_3(), fn x, y -> x * y end)

    assert {:ok, 42.0} = Tyyppi.T.apply(Types.test_fun_1(), &Types.f1_1/0, [])
    assert {:error, {:result, 42}} = Tyyppi.T.apply(Types.test_fun_1(), &Types.f1_2/0, [])
    assert {:error, {:result, :ok}} = Tyyppi.T.apply(Types.test_fun_1(), &Types.f1_3/0, [])
    assert {:ok, 4} = Tyyppi.T.apply(Types.test_fun_2(), &Types.f2_1/2, [2, 2])
    assert {:error, {:arity, 1}} = Tyyppi.T.apply(Types.test_fun_2(), &Types.f2_1/2, [42])

    assert {:error, {:args, [42, 42.0]}} =
             Tyyppi.T.apply(Types.test_fun_2(), &Types.f2_1/2, [42, 42.0])

    assert {:error, {:result, 1.0}} = Tyyppi.T.apply(Types.test_fun_2(), &Types.f2_2/2, [42, 42])

    assert {:ok, 84} = Tyyppi.T.apply(Types.test_fun_3(), &Types.f3_1/1, [2])
    assert {:error, {:result, 84.0}} = Tyyppi.T.apply(Types.test_fun_3(), &Types.f3_1/1, [2.0])
    assert {:error, {:arity, 0}} = Tyyppi.T.apply(Types.test_fun_3(), &Types.f3_1/1, [])

    assert_raise ArithmeticError, fn ->
      Tyyppi.T.apply(Types.test_fun_3(), &Types.f3_1/1, [:ok])
    end

    assert {:error, {:result, 84.0}} = Tyyppi.T.apply(Types.test_fun_3(), &Types.f3_2/1, [2])

    assert {:ok, "foo"} = Tyyppi.T.apply(&Atom.to_string/1, [:foo])
    assert {:error, {:args, ["foo"]}} = Tyyppi.T.apply(&Atom.to_string/1, ["foo"])
  end
end
