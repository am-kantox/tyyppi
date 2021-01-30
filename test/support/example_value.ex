defmodule Tyyppi.Example.Value do
  @moduledoc """
  Example of the structure defined with `Tyyppi.Struct.defstruct/1`, all values be `Tyyppi.Value`

  The original code of this module follows:

  ```elixir
  use Tyyppi

  @defaults foo: Value.atom(:ok), bar: Value.integer(42)
  defstruct foo: Value.t(), bar: Value.t()

  def validate_bar(%Value{value: value}) when value < 100, do: {:ok, value}
  def validate_bar(%Value{}), do: {:error, "Expected a value to be less than 100"}
  ```

  This module defines a struct having two fields, `foo` of a type `Value.t(atom())`,
  and `bar` of a type `Value.t(integer())`.
  """
  use Tyyppi

  @defaults foo: Value.atom(:ok), bar: Value.integer(42)
  defstruct foo: Value.t(atom()), bar: Value.t(integer())

  def validate_bar(%Value{value: value}) when value < 100, do: {:ok, value}
  def validate_bar(%Value{}), do: {:error, "Expected a value to be less than 100"}
end
