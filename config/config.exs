use Mix.Config


config :logger,
       backends: [
         :console,
         {LoggerFileBackend, :error_log},
         {LoggerFileBackend, :all}
       ]

config :logger,
       :error_log,
       path: "./log/wtf_error.log",
       level: :error

config :logger,
       :all,
       path: "./log/wtf.log",
       level: :debug

config :logger,
       :console,
       format: "[$time] [$level] $levelpad$metadata\n  $message\n",
       metadata: [:module, :msg],
         # this works in ConEmu
       colors: [
         enabled: true
       ]

config :ex_wtf,
       EctoStorage,
       adapter: Ecto.Adapters.Postgres,
       database: "changeme",
       username: "changeme",
       password: "changeme",
       hostname: "changeme"

config :ex_wtf, ecto_repos: [EctoStorage]