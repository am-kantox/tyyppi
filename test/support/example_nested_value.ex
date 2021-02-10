defmodule Tyyppi.Example.NestedValue do
  @moduledoc false

  use Tyyppi

  @defaults date_time: Value.date_time("1973-09-30 02:30:00Z"),
            struct: Tyyppi.Example.Value.as_value()
  defstruct date_time: Value.t(DateTime.t()), struct: Value.t(any())
end
