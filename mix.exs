defmodule ExWtf.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ex_wtf,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [
        :logger,
        :crypto,
        :poison,
        :timex,
        :ecto_timestamps,
        :postgrex,
        :ecto
      ],
      mod: {ExWtfMain, [config_file: "wtf_config.json"]}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:poison, "~> 3.1"},
      {:glob, "~> 0.0.9"},
      {:timex, "~> 3.1"},
      {:postgrex, ">= 0.0.0"},
      {:ecto, "~> 2.1"},
      {:ecto_timestamps, "~> 1.0.0"},
      {:logger_file_backend, "~> 0.0.10"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
    ]
  end
end
