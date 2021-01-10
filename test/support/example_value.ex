defmodule Tyyppi.ExampleValue do
  @moduledoc """
  Example of the structure defined with `Tyyppi.Struct.defstruct/1`, all values be `Tyyppi.Value`

  The original code of this module follows:

  ```elixir
  import Kernel, except: [defstruct: 1]
  import Tyyppi.Struct, only: [defstruct: 1]

  @defaults foo: Tyyppi.Value.atom(:ok), Tyyppi.Value.integer(42)
  defstruct foo: Tyyppi.Value.t(), bar: Tyyppi.Value.t()
  ```
  """
  import Kernel, except: [defstruct: 1]
  import Tyyppi.Struct, only: [defstruct: 1]

  alias Tyyppi.Value, as: V

  @defaults foo: V.atom(:ok), bar: V.integer(42)
  defstruct foo: V.t(), bar: V.t()

  def validate_bar(%V{value: value}) when value < 100, do: {:ok, value}
  def validate_bar(%V{}), do: {:error, "Expected a value to be less than 100"}
end
