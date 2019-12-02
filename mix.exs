defmodule Twirp.MixProject do
  use Mix.Project

  @version "0.2.0"

  def project do
    [
      app: :twirp,
      version: @version,
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      escript: escript(),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),

      description: description(),
      package: package(),
      name: "Twirp",
      source_url: "https://github.com/keathley/twirp",
      docs: docs()
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
  defp elixirc_paths(_), do: ["lib"]

  def escript do
    [main_module: Twirp.Protoc.CLI, name: "protoc-gen-twirp_elixir", app: nil]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.8"},
      {:tesla, "~> 1.3"},
      {:norm, "~> 0.9"},
      {:jason, "~> 1.1"},
      {:protobuf, "~> 0.5"},
      {:google_protos, "~>0.1"},
      {:hackney, "~> 1.15"},

      {:credo, "~> 1.1", only: [:dev]},
      {:bypass, "~> 1.0", only: [:dev, :test]},
      {:plug_cowboy, "~> 2.0", only: [:dev, :test]},
      {:ex_doc, "~> 0.19", only: [:dev, :test]},
      {:mox, "~> 0.5", only: [:test]},
    ]
  end

  def description do
    """
    Twirp provides an elixir implementation of the twirp rpc framework.
    """
  end

  def package do
    [
      name: "twirp",
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/keathley/twirp"}
    ]
  end

  def docs do
    [
      source_ref: "v#{@version}",
      source_url: "https://github.com/keathley/twirp",
      main: "Twirp"
    ]
  end
end
