defmodule ExTwelveData.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_twelve_data,
      version: "0.5.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),

      # Docs
      name: "ExTwelveData",
      source_url: "https://github.com/borgoat/ex_twelve_data/"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "Elixir client for Twelve Data."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/borgoat/ex_twelve_data/",
        "API Documentation - Twelve Data" => "https://twelvedata.com/docs"
      }
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # TODO should be optional
      {:castore, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:websockex, "~> 0.5"},
      {:ex_doc, "~> 0.40", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end
end
