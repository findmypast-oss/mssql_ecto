defmodule MssqlEcto.Mixfile do
  use Mix.Project

  def project do
    [app: :mssql_ecto,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     aliases: ["test.all": &test_all/1,
          "test.integration": &test_integration/1],
     test_paths: test_paths(Mix.env())]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [{:mssqlex, "~> 0.0.2"},
     {:ecto, "~> 2.1"}]
  end

  defp test_paths(:integration), do: ["integration/mssql"]
  defp test_paths(_), do: ["test"]

  defp test_integration(args) do
    args = if IO.ANSI.enabled?, do: ["--color" | args], else: ["--no-color" | args]
    System.cmd "mix", ["test" | args], into: IO.binstream(:stdio, :line),
                                       env: [{"MIX_ENV", "integration"}]
  end

  defp test_all(args) do
    Mix.Task.run "test", args
    {_, res} = test_integration(args)
    if res != 0, do: exit {:shutdown, 1}
  end
end
