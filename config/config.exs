import Config

level =
  case Mix.env() do
    :dev -> :debug
    _ -> :info
  end

config :logger,
  level: level,
  backends: [:console],
  compile_time_purge_matching: [
    [level_lower_than: level]
  ]

config :tyyppi, :strict, true
