defmodule Tyyppi.MixProject do
  use Mix.Project

  @app :tyyppi
  @version "0.6.0"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.10",
      compilers: compilers(Mix.env()),
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      consolidate_protocols: not (Mix.env() in [:dev, :test]),
      xref: [exclude: []],
      description: description(),
      package: package(),
      deps: deps(),
      aliases: aliases(),
      docs: docs(),
      releases: [],
      dialyzer: [
        plt_file: {:no_warn, ".dialyzer/dialyzer.plt"},
        plt_add_deps: :transitive,
        plt_add_apps: [:mix],
        list_unused_filters: true,
        ignore_warnings: ".dialyzer/ignore.exs"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:boundary, "~> 0.4", runtime: false},
      {:stream_data, "~> 0.5", only: [:dev, :test]},
      {:formulae, "~> 0.8", only: [:dev, :test]},
      {:jason, "~> 1.0", only: [:dev, :test, :ci]},
      {:credo, "~> 1.0", only: [:dev, :test, :ci]},
      {:dialyxir, "~> 1.0", only: [:dev, :test, :ci], runtime: false},
      {:ex_doc, "~> 0.11", only: :dev}
    ]
  end

  defp aliases do
    [
      quality: ["format", "credo --strict", "dialyzer"],
      "quality.ci": [
        "format --check-formatted",
        "credo --strict",
        "dialyzer"
      ]
    ]
  end

  defp description do
    """
    Library bringing erlang typespecs to runtime.

    Allows type validation, types structs with upserts validation and more.
    """
  end

  defp package do
    [
      name: @app,
      files: ~w|lib .formatter.exs .dialyzer/ignore.exs mix.exs README* LICENSE|,
      maintainers: ["Aleksei Matiushkin"],
      licenses: ["Kantox LTD"],
      links: %{
        "GitHub" => "https://github.com/am-kantox/#{@app}",
        "Docs" => "https://hexdocs.pm/#{@app}"
      }
    ]
  end

  defp docs do
    [
      main: "getting-started",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/#{@app}",
      logo: "stuff/#{@app}-48x48.png",
      source_url: "https://github.com/am-kantox/#{@app}",
      assets: "stuff/images",
      extras: ~w[stuff/getting-started.md],
      groups_for_modules: [
        Internals: [
          Tyyppi.Stats,
          Tyyppi.T
        ],
        Examples: [
          Tyyppi.ExamplePlainStructValue,
          Tyyppi.ExamplePlainStruct,
          Tyyppi.ExampleValue
        ]
      ]
    ]
  end

  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:ci), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp compilers(:prod), do: Mix.compilers()
  defp compilers(_), do: [:boundary | Mix.compilers()]
end
