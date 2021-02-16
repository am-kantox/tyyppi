defmodule Tyyppi.Valuable do
  @moduledoc """
  The behaviour all participants of the `Tyyppi`’s operations
    should have implemented.

  It’s implemented by `Tyyppi.Value` and `Tyyppi.Struct`, making them available
    for deep nested validations, coercion and generation.
  """

  @typedoc "Type of the value behind the implementation"
  @type value :: any()

  @typedoc """
  Type returned from coercions and validations, typical pair of ok/error tuples,
    involving the `value()` as a main type behind
  """
  @type either :: {:ok, value()} | {:error, any()}

  @typedoc """
  Type of the generation function, basically returning a stream of generated values
  """
  if StreamData == Tyyppi.Value.Generations.prop_test() do
    @type generation :: StreamData.t(value())
  else
    @type generation :: Enumerable.t()
  end

  ##############################################################################

  @doc """
  The validation function, receiving the `value()`
  """
  @callback validate(value()) :: either()

  @doc """
  The coercion function, receiving the `value()`
  """
  @callback coerce(value()) :: either()

  @doc """
  The generation function, returning the generator for the whole
  """
  @callback generation(value()) :: generation()
end
