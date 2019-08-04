defmodule MssqlEcto.Mixfile do
  use Mix.Project

  def project() do
    [
      app: :mssql_ecto,
      version: "1.2.0",
      description: "Ecto Adapter for Microsoft SQL Server. Using Mssqlex.",
      elixir: "~> 1.8",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      test_paths: ["integration/mssql", "test"],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        "test.integration": :test,
        "test.unit": :test,
        coveralls: :test,
        "coveralls.travis": :test
      ],
      name: "MssqlEcto",
      source_url: "https://github.com/findmypast-oss/mssql_ecto",
      docs: [main: "readme", extras: ["README.md"]]
    ]
  end

  def application() do
    [extra_applications: [:logger]]
  end

  defp deps() do
    [
      #{:mssqlex, "~> 1.1.0"},
      #{:mssqlex, git: "https://github.com/whossname/mssqlex.git", branch: "db_connection_2.0"},
      {:mssqlex, path: "../mssqlex"},

      {:ecto_sql, "~> 3.1"},
      {:db_connection, path: "../db_connection", override: true},

      # tooling
      {:ex_doc, "~> 0.15", only: :dev, runtime: false},
      {:dialyxir, "~> 0.4", only: [:dev]},
      {:excoveralls, "~> 0.6", only: :test},
      {:inch_ex, "~> 0.5", only: :docs},
    ]
  end

  defp package() do
    [
      name: :mssql_ecto,
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Steven Blowers", "Jae Bach Hardie"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/findmypast-oss/mssql_ecto"}
    ]
  end
end
