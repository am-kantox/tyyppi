defmodule Tyyppi.ExampleValue do
  @moduledoc """
  Example of the structure defined with `Tyyppi.Struct.defstruct/1`, all values be `Tyyppi.Value`

  The original code of this module follows:

  ```elixir
  import Kernel, except: [defstruct: 1]
  import Tyyppi.Struct, only: [defstruct: 1]

  @defaults foo: Tyyppi.Value.atom_value(), Tyyppi.Value.integer_value()
  defstruct foo: Tyyppi.Value.t(), bar: Tyyppi.Value.t()
  ```
  """
  import Kernel, except: [defstruct: 1]
  import Tyyppi.Struct, only: [defstruct: 1]

  @defaults foo: Tyyppi.Value.atom(:ok), bar: Tyyppi.Value.integer(42)
  defstruct foo: Tyyppi.Value.t(), bar: Tyyppi.Value.t()
end
