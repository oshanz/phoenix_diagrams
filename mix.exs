defmodule ExDiag.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_diag,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:phoenix_live_view, "~> 1.2"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}

      # {:file_system, "~> 1.1"}
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp aliases do
    [
      precommit: [
        "format",
        "compile --warnings-as-errors",
        "credo --strict",
        "test"
      ]
    ]
  end
end
