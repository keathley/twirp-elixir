defmodule Twirp.MixProject do
  use Mix.Project

  def project do
    [
      app: :twirp,
      version: "0.1.0",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.8"},
      {:tesla, "~> 1.3"},
      {:norm, "~> 0.8"},
      {:jason, "~> 1.1"},
      {:protobuf, "~> 0.5"},
      {:google_protos, "~>0.1"},
      {:hackney, "~> 1.15"},

      {:mox, "~> 0.5", only: [:dev, :test]},
      {:bypass, "~> 1.0", only: [:dev, :test]},
      {:plug_cowboy, "~> 2.0", only: [:dev, :test]},
    ]
  end
end
