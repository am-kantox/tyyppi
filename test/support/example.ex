defmodule Tyyppi.Example do
  @moduledoc """
  Example of the structure defined with `Tyyppi.Struct.defstruct/1`

  The original code of this module follows:

  ```elixir
  import Kernel, except: [defstruct: 1]
  import Tyyppi.Struct, only: [defstruct: 1]

  @typedoc "The user type defined before `defstruct/1` declaration"
  @type my_type :: :ok | {:error, term()}

  defstruct foo: atom(), bar: GenServer.on_start(), baz: my_type()
  ```
  """
  import Kernel, except: [defstruct: 1]
  import Tyyppi.Struct, only: [defstruct: 1]

  @typedoc "The user type defined before `defstruct/1` declaration"
  @type my_type :: :ok | {:error, term()}

  defstruct foo: atom(), bar: GenServer.on_start(), baz: my_type()
end
