{:ok, _pid} = Tyyppi.Stats.start_link(callback: &Test.Tyyppi.rehashed/2)
ExUnit.start()
