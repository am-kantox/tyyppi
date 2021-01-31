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

  @defaults foo: Value.optional(Value.atom()),
            bar: Value.integer(42),
            baz: Value.date_time(~U[1973-09-30 02:46:30Z])
  defstruct foo: Value.t(atom()), bar: Value.t(integer()), baz: Value.t(DateTime.t())

  def validate_bar(%Value{value: value}) when value < 100, do: {:ok, value}
  def validate_bar(%Value{}), do: {:error, "Expected a value to be less than 100"}

  @spec as_value(keyword()) :: Value.t()
  @doc "Factory for `#{__MODULE__}` wrapped by `Tyyppi.Value`"
  def as_value(values \\ []) do
    value = struct!(__MODULE__, values)

    %Tyyppi.Value{
      value: value,
      type: Tyyppi.parse(Tyyppi.Example.Value.t()),
      validation: &__MODULE__.validate/1,
      generation: &__MODULE__.generation/1
    }
  end

  @doc false
  def generation(%Value{value: value}), do: super(value)
  def generation(value), do: super(value)
end
