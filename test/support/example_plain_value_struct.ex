defmodule Tyyppi.ExamplePlainValueStruct do
  @moduledoc false

  import Kernel, except: [defstruct: 1]
  import Tyyppi.Struct, only: [defstruct: 1]

  alias Tyyppi.Value

  @type my_type :: DateTime.t()

  @defaults foo: Value.optional(Value.atom()),
            bar: Value.date_time(42),
            baz: Value.date_time(~U[1973-09-30 02:46:30Z])
  defstruct foo: nil | Value.t(), bar: Value.t(), baz: Value.t()

  defp cast_baz(true), do: DateTime.utc_now()
  defp cast_baz(value), do: value
end
