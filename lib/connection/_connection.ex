if Code.ensure_loaded?(Mssqlex) do
  defmodule MssqlEcto.Connection do
    @moduledoc false

    @default_port 1433
    @behaviour Ecto.Adapters.SQL.Connection

    alias MssqlEcto.Connection.{DDL, Query}

    import MssqlEcto.Connection.Helper
    require Logger

    ## Module and Options

    @impl true

    @spec child_spec(Keyword.t()) :: Supervisor.Spec.spec()
    def child_spec(opts) do
      opts
      |> Keyword.put_new(:port, @default_port)
      |> Mssqlex.child_spec()
    end

    @impl true
    def to_constraints(%Mssqlex.Error{} = error), do: error.constraint_violations

    ## Query
    @impl true
    def prepare_execute(conn, name, sql, params, opts) do
      Mssqlex.prepare_execute(conn, name, sql, params, opts)
    end

    @impl true
    def query(conn, sql, params, opts) do
      Mssqlex.query(conn, sql, params, opts)
    end

    @impl true
    def execute(conn, %{ref: ref} = query, params, opts) do
      case DBConnection.execute(conn, query, params, opts) do
        {:ok, %{ref: ^ref}, result} ->
          {:ok, result}

        {:ok, _, _} = ok ->
          ok

        {:error, %Mssqlex.Error{} = err} ->
          {:reset, err}

        {:error, %Mssqlex.Error{odbc_code: :feature_not_supported} = err} ->
          {:reset, err}

        {:error, _} = error ->
          error
      end
    end

    @impl true
    def stream(conn, sql, params, opts) do
      Mssqlex.stream(conn, sql, params, opts)
    end

    # query
    @impl true
    def all(query), do: Query.all(query)

    @impl true
    def update_all(query, prefix \\ nil), do: Query.update_all(query, prefix)

    @impl true
    def delete_all(query), do: Query.delete_all(query)

    @impl true
    def insert(prefix, table, header, rows, on_conflict, returning) do
      values =
        if header == [] do
          [
            Query.output(returning, "INSERTED"),
            " DEFAULT VALUES "
            | intersperse_map(rows, ?,, fn _ -> "" end)
          ]
        else
          [
            ?\s,
            ?(,
            intersperse_map(header, ?,, &quote_name/1),
            ")",
            Query.output(returning, "INSERTED"),
            " VALUES " | Query.insert_all(rows, 1)
          ]
        end

      [
        "INSERT INTO ",
        quote_table(prefix, table),
        Query.insert_as(on_conflict),
        values,
        Query.on_conflict(on_conflict, header)
      ]
    end

    @impl true
    def update(prefix, table, fields, filters, returning) do
      {fields, count} =
        intersperse_reduce(fields, ", ", 1, fn field, acc ->
          {[quote_name(field), " = ?"], acc + 1}
        end)

      {filters, _count} = intersperse_reduce(filters, " AND ", count, &condition_reducer/2)

      [
        "UPDATE ",
        quote_table(prefix, table),
        " SET ",
        fields,
        Query.output(returning, "INSERTED"),
        " WHERE ",
        filters
      ]
    end

    @impl true
    def delete(prefix, table, filters, returning) do
      {filters, _} = intersperse_reduce(filters, " AND ", 1, &condition_reducer/2)

      [
        "DELETE FROM ",
        quote_table(prefix, table),
        Query.output(returning, "DELETED"),
        " WHERE ",
        filters
      ]
    end

    defp condition_reducer({field, nil}, acc) do
      {[quote_name(field), " IS NULL"], acc}
    end

    defp condition_reducer({field, _value}, acc) do
      {[quote_name(field), " = ?"], acc + 1}
    end

    defp condition_reducer(field, acc) do
      {[quote_name(field), " = ?"], acc + 1}
    end

    # DDL
    @impl true
    def execute_ddl(args), do: DDL.execute(args)

    @impl true
    def ddl_logs(result), do: DDL.logs(result)

    @impl true
    def table_exists_query(table), do: DDL.table_exists_query(table)
  end
end
