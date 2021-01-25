defmodule Tyyppi.ExampleNestedStruct do
  @moduledoc """
  Example of the nested structure defined with `Tyyppi.Struct.defstruct/1`
  """
  import Kernel, except: [defstruct: 1]
  import Tyyppi.Struct, only: [defstruct: 1]

  alias Tyyppi.Value

  # @type dt :: %DateTime{}
  @type dt :: binary()

  @defaults date_time: Value.string("1973-09-30 02:30:00Z"),
            struct: Value.struct(%Tyyppi.ExamplePlainStruct{})
  defstruct date_time: DateTime.t(), struct: Tyyppi.ExamplePlainStruct.t()
end
