defmodule PhoenixDiagrams.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/oshanz/umlbook"

  def project do
    [
      app: :phoenix_diagrams,
      version: @version,
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  defp description do
    "Embeds a Mermaid/PlantUML diagram browser LiveView into a host Phoenix application."
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Demo app" => "#{@source_url}/tree/main/demo"
      },
      files: ~w(
        lib
        mix.exs
        README.md
        LICENSE
        usage-rules.md
        .formatter.exs
        priv/static/phoenix_diagrams/build/app.css
        priv/static/phoenix_diagrams/build/bundle.js
      )
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md"]
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
      {:lazy_html, ">= 0.1.0", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:file_system, "~> 1.1", only: [:dev, :test]}
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

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
