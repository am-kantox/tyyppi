{:ok, _pid} = Tyyppi.Stats.start_link(callback: &Test.Tyyppi.Rehasher.rehashed/2)
ExUnit.start()
