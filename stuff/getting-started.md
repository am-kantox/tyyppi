# Tyyppi

Library bringing erlang typespecs to runtime.

Provides on-the-fly type validation, typed structs with upserts validation and more.

## Dealing with Types

`Tyyppi` allows the runtime validation of types, specified as _specs_. To use
all the features, one should start `Tyyppi.Stats` process within
the application supervision tree.

Internally, the library keeps the types as instances of `Tyyppi.T` struct.

### `Tyyppi.parse/1`

Accepts the type and returns back `Tyyppi.T` instance. It’s unlikely you’d need
to call this macro directly.

```elixir
iex|tyyppi|1 ▶ Tyyppi.parse atom
#⇒ %Tyyppi.T{
#    definition: {:type, 0, :atom, []},
#    module: nil,
#    name: nil,
#    params: [],
#    quoted: {:atom, [], []},
#    source: nil,
#    type: :built_in
#  }
```

Remote types are also supported, if they are known to the system. To get
an access to remote types, one must start `Tyyppi.Stats` process by calling
`Tyyppi.Stats.start_link/1`.

```elixir
iex|tyyppi|2 ▶ Tyyppi.parse GenServer.on_start
#⇒ %Tyyppi.T{
#    definition: {:type, 700, :union,
#     [
#       {:type, 0, :tuple, [{:atom, 0, :ok}, {:type, 700, :pid, []}]},
#       {:atom, 0, :ignore},
#       {:type, 0, :tuple,
#        [
#          {:atom, 0, :error},
#          {:type, 700, :union,
#           [
#             {:type, 0, :tuple,
#              [{:atom, 0, :already_started}, {:type, 700, :pid, []}]},
#             {:type, 700, :term, []}
#           ]}
#        ]}
#     ]},
#    module: GenServer,
#    name: :on_start,
#    params: [],
#    quoted: {{:., [], [GenServer, :on_start]}, [], []},
#    source: ".../lib/elixir/ebin/Elixir.GenServer.beam",
#    type: :type
#  }
```

### `Tyyppi.of?/2`

Validates the term given as the second parameter against type given as the first
parameter.

```elixir
iex|tyyppi|3 ▶ Tyyppi.of? GenServer.on_start(), {:ok, self()}
#⇒ true
iex|tyyppi|4 ▶ Tyyppi.of? GenServer.on_start(), :ok
#⇒ false
```

### `Tyyppi.of_type?/2`

The same as `Tyyppi.of?/2` but it expects an instance of `Tyyppy.T`
(as returned by `Tyyppi.parse/1`) as the first parameter.

```elixir
iex|tyyppi|5 ▶ type = Tyyppi.parse(GenServer.on_start)
iex|tyyppi|6 ▶ Tyyppi.of_type? type, {:ok, self()}
#⇒ true
```

### `Tyyppi.apply/3`

**Experimental** accepts spec type, function and the list of arguments,
checks whether the argument list conforms the spec, applies the function if so,
checks the result against the spec and returns either `{:ok, result}` tuple
or `{:error, {reason, value}}` tuple otherwise.

See `Tyyppi.apply/3` docs for examples and details.

## Dealing with Structs

`Tyyppi` provides the handy way to build typed structs. The struct declared with
`Tyyppi.Struct.defstruct/1` automatically declares the public type with all the
fields properly declared, as well as provides the ability to introduce
additional validations and casting on per-field basis. It also optionally
exposes `Access` implementation that also would allow upserts if and only the
casted value passed validations (both againts the type and a custom validator,
if it was declared.)

