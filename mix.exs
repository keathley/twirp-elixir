defmodule Twirp.MixProject do
  use Mix.Project

  def project do
    [
      app: :twirp,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:plug, "~> 1.8"},
      {:tesla, "~> 1.3"},
      {:norm, "~> 0.8"},
      {:jason, "~> 1.1"},
      {:protobuf, "~> 0.5"},
      {:google_protos, "~>0.1"},

      {:plug_cowboy, "~> 2.0", only: [:dev, :test]},
    ]
  end
end
