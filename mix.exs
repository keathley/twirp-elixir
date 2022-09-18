defmodule Twirp.MixProject do
  use Mix.Project

  @version "0.8.0"
  @source_url "https://github.com/keathley/twirp-elixir"

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

      dialyzer: [
        plt_add_deps: :apps_direct,
        plt_add_apps: [:finch, :hackney],
      ],

      xref: [
        exclude: [
          Finch,
          :hackney,
          :hackney_pool,
        ]
      ],

      description: description(),
      package: package(),
      aliases: aliases(),
      preferred_cli_env: ["test.generation": :test],
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
      {:plug, "~> 1.13"},
      {:norm, "~> 0.9"},
      {:jason, "~> 1.1"},
      {:protobuf, "~> 0.11"},
      {:google_protos, "~>0.3"},
      {:finch, "~> 0.6", optional: true},
      {:hackney, "~> 1.17", optional: true},
      {:telemetry, "~> 0.4 or ~> 1.0"},

      {:bypass, "~> 2.1", only: [:dev, :test]},
      {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.19", only: [:dev, :test], runtime: false},
      {:plug_cowboy, "~> 2.0", only: [:dev, :test]},
      {:mox, "~> 1.0", only: [:test]},
    ]
  end

  def aliases do
    [
      "test.generation": [
        "escript.build",
        "escript.install --force",
        &generate_protos/1,
        "test"
      ]
    ]
  end

  defp generate_protos(_) do
    result = System.cmd("protoc", [
      "--proto_path=./test/support",
      "--elixir_out=./test/support",
      "--twirp_elixir_out=./test/support",
      "./test/support/service.proto",
    ])

    case result do
      {_, 0} ->
        :ok

      {error, code} ->
        throw {error, code}
    end
  end

  def description do
    """
    Twirp provides an Elixir implementation of the Twirp RPC framework.
    """
  end

  def package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  def docs do
    [
      source_ref: "v#{@version}",
      source_url: @source_url,
      main: "Twirp"
    ]
  end
end
