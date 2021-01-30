defmodule Tyyppi.Example.Struct do
  @moduledoc """
  Example of the structure defined with `Tyyppi.Struct.defstruct/1`

  The original code of this module follows:

  ```elixir
  use Tyyppi

  @typedoc "The user type defined before `defstruct/1` declaration"
  @type my_type :: :ok | {:error, term()}

  @defaults bar: {:ok, :erlang.list_to_pid('<0.0.0>')}, baz: {:error, :reason}
  defstruct foo: nil | atom(), bar: GenServer.on_start(), baz: my_type()
  ```
  """
  use Tyyppi

  @typedoc "The user type defined before `defstruct/1` declaration"
  @type my_type :: :ok | {:error, term()}

  @typedoc "The user type exported"
  @type my_map_1 :: %{foo: atom()}
  @type my_map_2 :: %{required(atom()) => integer()}
  @type my_map_3 :: %{optional(binary()) => my_type()}

  @type my_struct :: %DateTime{}

  @defaults bar: {:ok, :erlang.list_to_pid('<0.0.0>')}, baz: {:error, :reason}
  defstruct foo: atom(), bar: GenServer.on_start(), baz: my_type()

  defp cast_baz(true), do: :ok
  defp cast_baz(false), do: {:error, false}
  defp cast_baz(value), do: value
end
