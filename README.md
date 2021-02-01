# Tyyppi    [![Kantox ❤ OSS](https://img.shields.io/badge/❤-kantox_oss-informational.svg)](https://kantox.com/)  [![Test](https://github.com/am-kantox/tyyppi/workflows/Test/badge.svg)](https://github.com/am-kantox/tyyppi/actions?query=workflow%3ATest)  [![Dialyzer](https://github.com/am-kantox/tyyppi/workflows/Dialyzer/badge.svg)](https://github.com/am-kantox/tyyppi/actions?query=workflow%3ADialyzer)

**Library bringing erlang typespecs to runtime.**

Provides on-the-fly type validation, typed structs with upserts validation and more.

## Installation

```elixir
def deps do
  [
    {:tyyppi, "~> 0.1"}
  ]
end
```

## Changelog

- **`0.8.0`** — `Tyyppi.Valuable` behaviour + better docs
- **`0.7.0`** — Generators + Collectable + Enumerable + Nested Structs
- **`0.6.0`** — `Tyyppi.Value` for `Struct` + `Jason.Encoder` if `Jason` is presented + bugfixes
- **`0.5.0`** — `Tyyppi.Value` + constructors + `~t||` sigil to produce `Tyyppi` types
- **`0.4.0`** — per-field coercions and validations via `cast_field/1` and `validate_field/1`
- **`0.3.0`** — use `:ets` for type information when the process was not started

## [Documentation](https://hexdocs.pm/tyyppi)
