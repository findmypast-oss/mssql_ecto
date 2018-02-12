Code.require_file("../deps/ecto/integration_test/support/types.exs", __DIR__)
ExUnit.start()
# ExUnit.configure(exclude: [skip: true])

defmodule MssqlEcto.Case do
  use ExUnit.CaseTemplate

  using _ do
    quote do
      import MssqlEcto.Case
      alias MssqlEcto.Connection, as: SQL
    end
  end

  def normalize(query, operation \\ :all, counter \\ 0) do
    {query, _params, _key} =
      Ecto.Query.Planner.prepare(query, operation, MssqlEcto, counter)

    case Ecto.Query.Planner.normalize(query, operation, MssqlEcto, counter) do
      # Ecto v2.2 onwards
      {%Ecto.Query{} = query, _} ->
        query

      # Ecto v2.1 and previous
      %Ecto.Query{} = query ->
        query
    end
  end
end
