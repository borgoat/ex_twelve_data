defmodule ExTwelveData.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_twelve_data,
      version: "0.5.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      aliases: aliases(),
      dialyzer: [flags: [:unmatched_returns, :extra_return, :missing_return]],
      # A floor, not a target: connecting and reconnecting are only exercised by the live integration test.
      test_coverage: [summary: [threshold: 80]],
      # Resolve only releases older than 7 days, so a compromised release has time to be caught.
      hex: [cooldown: "7d"],

      # Docs
      name: "ExTwelveData",
      source_url: "https://github.com/borgoat/ex_twelve_data/",
      docs: [
        main: "readme",
        extras: ["README.md", "CHANGELOG.md"],
        # A changelog names modules that are private or gone.
        skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
      ]
    ]
  end

  # The gate runs in one environment, so it compiles once and can run the tests.
  def cli do
    [preferred_envs: [ci: :test]]
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
      {:ex_doc, "~> 0.40", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  # `mix ci` is the whole gate: CI runs exactly this, so run it before opening a pull request.
  # The `cmd` linters come from the Nix devshell.
  defp aliases do
    [
      ci: [
        "deps.unlock --check-unused",
        "hex.audit",
        "format --check-formatted",
        # --force: an up-to-date _build would skip (and not warn about) unchanged files.
        "compile --warnings-as-errors --force",
        "credo --strict",
        "dialyzer",
        "docs --warnings-as-errors",
        "test --cover --warnings-as-errors",
        "cmd typos",
        "cmd actionlint",
        "cmd zizmor --offline .github"
      ]
    ]
  end
end
