import Config

level =
  case Mix.env() do
    :test -> :info
    :dev -> :debug
  end

config :logger,
  level: level,
  backends: [:console],
  compile_time_purge_matching: [
    [level_lower_than: level]
  ]
