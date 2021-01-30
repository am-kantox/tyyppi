defmodule Tyyppi.Example.Nested do
  @moduledoc """
  Example of the nested structure defined with `Tyyppi.Struct.defstruct/1`
  """

  use Tyyppi

  # @type dt :: %DateTime{}
  @type dt :: binary()

  @defaults date_time: Value.date_time("1973-09-30 02:30:00Z"),
            struct: %Tyyppi.Example.Value{}
  defstruct date_time: Value.t(DateTime.t()), struct: Tyyppi.Example.Value.t()
end
