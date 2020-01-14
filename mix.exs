defmodule MssqlEcto.Mixfile do
  use Mix.Project

  def project() do
    [
      app: :mssql_ecto,
      version: "2.0.0-beta.0",
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
      mssqlex_path(),
      {:ecto_sql, "~> 3.2"},
      {:db_connection, "~> 2.1"},

      # tooling
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.6", only: :test},
      {:inch_ex, "~> 0.5", only: :docs}
    ]
  end

  defp mssqlex_path() do
    if path = System.get_env("MSSQLEX_PATH") do
      {:mssqlex, path: path}
    else
      {:mssqlex, "2.0.0-beta.0"}
    end
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
