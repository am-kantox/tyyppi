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

        @type test_fun_1 :: (() -> type)
        @type test_fun_2 :: (type1, type2 -> type)
        @type test_fun_3 :: (... -> type)
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

    assert Tyyppi.T.of?(Tyyppi.T.test_binary_3(), <<>>)
    assert Tyyppi.T.of?(Tyyppi.T.test_binary_3(), <<4::3>>)
    assert Tyyppi.T.of?(Tyyppi.T.test_binary_3(), <<4::3, 5::3>>)
    assert Tyyppi.T.of?(Tyyppi.T.test_binary_3(), <<4::6>>)
    refute Tyyppi.T.of?(Tyyppi.T.test_binary_3(), <<4::4>>)
    refute Tyyppi.T.of?(Tyyppi.T.test_binary_3(), :foo)

    refute Tyyppi.T.of?(Tyyppi.T.test_binary_4(), <<>>)
    assert Tyyppi.T.of?(Tyyppi.T.test_binary_4(), <<4::3>>)
    assert Tyyppi.T.of?(Tyyppi.T.test_binary_4(), <<1::1, 1::1, 1::1>>)
    refute Tyyppi.T.of?(Tyyppi.T.test_binary_4(), <<4::6>>)
    refute Tyyppi.T.of?(Tyyppi.T.test_binary_4(), :foo)
  end

  test "fun" do
    assert Tyyppi.T.of?(Tyyppi.T.test_fun_1(), fn -> 42.0 end)
    refute Tyyppi.T.of?(Tyyppi.T.test_fun_1(), fn x -> x end)
    assert Tyyppi.T.of?(Tyyppi.T.test_fun_2(), fn x, y -> x * y end)
    refute Tyyppi.T.of?(Tyyppi.T.test_fun_2(), fn x -> x end)
    assert Tyyppi.T.of?(Tyyppi.T.test_fun_3(), fn -> 42.0 end)
    assert Tyyppi.T.of?(Tyyppi.T.test_fun_3(), fn x -> x * 42.0 end)
    assert Tyyppi.T.of?(Tyyppi.T.test_fun_3(), fn x, y -> x * y end)
  end
end
