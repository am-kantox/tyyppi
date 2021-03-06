defmodule Test.Tyyppi.Rehasher do
  @moduledoc false

  require Logger
  use Boundary

  @spec rehashed(added :: Tyyppi.Stats.info(), removed :: Tyyppi.Stats.info()) :: any()
  def rehashed(added, removed) when map_size(removed) == 0 and map_size(added) > 1,
    do: :ok

  def rehashed(added, removed),
    do: Logger.debug(inspect({added, removed}, label: "[🚱 Rehashed]"))
end
