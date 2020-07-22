defmodule Tyyppi.MixProject do
  use Mix.Project

  def project do
    [
      app: :tyyppi,
      version: "0.1.0",
      elixir: "~> 1.10",
      compilers: [:boundary | compilers(Mix.env())],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:boundary, "~> 0.4"},
      {:credo, "~> 1.0", only: [:dev, :ci]},
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

  defp compilers(:prod), do: Mix.compilers()
  defp compilers(_), do: [:boundary | Mix.compilers()]
end
