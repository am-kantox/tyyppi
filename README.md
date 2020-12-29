# Tyyppi    [![Kantox ❤ OSS](https://img.shields.io/badge/❤-kantox_oss-informational.svg)](https://kantox.com/)  ![Test](https://github.com/am-kantox/tyyppi/workflows/Test/badge.svg)  ![Dialyzer](https://github.com/am-kantox/tyyppi/workflows/Dialyzer/badge.svg)

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

- **`0.3.0`** — use `:ets` for type information when the process was not started

## [Documentation](https://hexdocs.pm/tyyppi).
