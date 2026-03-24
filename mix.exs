defmodule Lobber.MixProject do
  use Mix.Project

  def project do
    [
      app: :lobber,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Lobber.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mint, "~> 1.7.1"},
      {:castore, "~> 1.0.17"},
      {:jason, "~> 1.4.4"},
      {:tesla, "~> 1.11"},
      {:gun, "~> 2.2"},
      {:idna, "~> 6.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
