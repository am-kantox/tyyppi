defmodule Tyyppi do
  @moduledoc """
  Documentation for `Tyyppi`.
  """

  use Boundary, exports: [T, Stats]

  alias Tyyppi.T
  require T

  defmacro parse(ast), do: quote(do: T.parse(unquote(ast)))
  defmacro of?(type, term), do: quote(do: T.of?(unquote(type), unquote(term)))
  defmacro apply(fun, args), do: quote(do: T.apply(unquote(fun), unquote(args)))

  defmacro apply(type, fun, args),
    do: quote(do: T.apply(unquote(type), unquote(fun), unquote(args)))
end
