defmodule Tyyppi.Example.Types do
  @moduledoc false

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
