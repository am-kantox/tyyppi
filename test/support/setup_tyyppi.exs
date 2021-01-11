if match?({:module, _}, Code.ensure_compiled(Tyyppi)) do
  quote do
    alias Tyyppi.{Stats, T, Value, ExampleValue}

    require Tyyppi

    import Kernel, except: [defstruct: 1]
    import Tyyppi.Struct, only: [defstruct: 1]

    Tyyppi.Stats.start_link()
  end
else
  IO.puts("\n✗ Tyyppi features are not set. Run `iex -S mix` to enable.")
end
