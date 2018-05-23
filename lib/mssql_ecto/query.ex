defmodule MssqlEcto.Query do
  alias MssqlEcto.QueryString

  import MssqlEcto.Helpers

  @doc """
  Receives a query and must return a SELECT query.
  """
  @spec all(query :: Ecto.Query.t()) :: String.t()
  def all(query) do
    sources = QueryString.create_names(query)

    {select_distinct, order_by_distinct} =
      QueryString.distinct(query.distinct, sources, query)

    from = QueryString.from(query, sources)
    select = QueryString.select(query, select_distinct, sources)
    join = QueryString.join(query, sources)
    where = QueryString.where(query, sources)
    group_by = QueryString.group_by(query, sources)
    having = QueryString.having(query, sources)
    order_by = QueryString.order_by(query, order_by_distinct, sources)
    offset = QueryString.offset(query, sources)
    lock = QueryString.lock(query.lock)

    IO.iodata_to_binary([
      select,
      from,
      join,
      where,
      group_by,
      having,
      order_by,
      offset | lock
    ])
  end

  @doc """
  Receives a query and values to update and must return an UPDATE query.
  """
  @spec update_all(query :: Ecto.Query.t()) :: String.t()
  def update_all(%{from: from} = query, prefix \\ nil) do
    sources = QueryString.create_names(query)
    {from, name} = get_source(query, sources, 0, from)

    prefix = prefix || ["UPDATE ", name | " SET "]
    table_alias = [" FROM ", from, " AS ", name]
    fields = QueryString.update_fields(query, sources)
    join = QueryString.join(query, sources)
    where = QueryString.where(query, sources)

    IO.iodata_to_binary([
      prefix,
      fields,
      returning(query, sources, "INSERTED"),
      table_alias,
      join,
      where
    ])
  end

  @doc """
  Receives a query and must return a DELETE query.
  """
  @spec delete_all(query :: Ecto.Query.t()) :: String.t()
  def delete_all(%{from: from} = query) do
    sources = QueryString.create_names(query)
    {from, name} = get_source(query, sources, 0, from)

    join = QueryString.join(query, sources)
    where = QueryString.where(query, sources)

    IO.iodata_to_binary([
      "DELETE ",
      name,
      returning(query, sources, "DELETED"),
      " FROM ",
      from,
      " AS ",
      name,
      join,
      where
    ])
  end

  @doc """
  Returns an INSERT for the given `rows` in `table` returning
  the given `returning`.
  """
  @spec insert(
          prefix :: String.t(),
          table :: String.t(),
          header :: [atom],
          rows :: [[atom | nil]],
          on_conflict :: Ecto.Adapter.on_conflict(),
          returning :: [atom]
        ) :: String.t()
  def insert(prefix, table, header, rows, on_conflict, returning) do
    included_fields =
      header
      |> Enum.filter(fn value -> Enum.any?(rows, fn row -> value in row end) end)

    if included_fields === [] do
      [
        "INSERT INTO ",
        quote_table(prefix, table),
        returning(returning, "INSERTED"),
        " DEFAULT VALUES ; "
      ]
      |> List.duplicate(length(rows))
      |> IO.iodata_to_binary()
    else
      included_rows =
        Enum.map(rows, fn row ->
          row
          |> Enum.zip(header)
          |> Enum.filter(fn {_row, col} -> col in included_fields end)
          |> Enum.map(fn {row, _col} -> row end)
        end)

      fields = intersperse_map(included_fields, ?,, &quote_name/1)

      IO.iodata_to_binary([
        "INSERT INTO ",
        quote_table(prefix, table),
        " (",
        fields,
        ")",
        returning(returning, "INSERTED"),
        " VALUES ",
        insert_all(included_rows, 1),
        on_conflict(on_conflict, included_fields)
      ])
    end
  end

  defp on_conflict({:raise, _, []}, _header) do
    []
  end

  defp on_conflict(_, _header) do
    error!(nil, ":on_conflict options other than :raise are not yet supported")
  end

  defp insert_all(rows, counter) do
    intersperse_reduce(rows, ?,, counter, fn row, counter ->
      {row, counter} = insert_each(row, counter)
      {[?(, row, ?)], counter}
    end)
    |> elem(0)
  end

  defp insert_each(values, counter) do
    intersperse_reduce(values, ?,, counter, fn
      nil, counter ->
        {"DEFAULT", counter}

      _, counter ->
        {[?? | Integer.to_string(counter)], counter + 1}
    end)
  end

  defp returning(%Ecto.Query{select: nil}, _sources, _), do: []

  defp returning(
         %Ecto.Query{select: %{fields: fields}} = query,
         _sources,
         operation
       ),
       do: [
         " OUTPUT "
         | QueryString.select_fields(fields, {{nil, operation, nil}}, query)
       ]

  defp returning([], _), do: []

  defp returning(returning, operation),
    do: [
      " OUTPUT "
      | Enum.map_join(returning, ", ", fn column ->
          [operation, ?. | quote_name(column)]
        end)
    ]

  @doc """
  Returns an UPDATE for the given `fields` in `table` filtered by
  `filters` returning the given `returning`.
  """
  @spec update(
          prefix :: String.t(),
          table :: String.t(),
          fields :: [atom],
          filters :: [atom],
          returning :: [atom]
        ) :: String.t()
  def update(prefix, table, fields, filters, returning) do
    {fields, count} =
      intersperse_reduce(fields, ", ", 1, fn field, acc ->
        {[quote_name(field), " = ?" | Integer.to_string(acc)], acc + 1}
      end)

    {filters, _count} =
      intersperse_reduce(filters, " AND ", count, fn field, acc ->
        {[quote_name(field), " = ?" | Integer.to_string(acc)], acc + 1}
      end)

    IO.iodata_to_binary([
      "UPDATE ",
      quote_table(prefix, table),
      " SET ",
      fields,
      returning(returning, "INSERTED"),
      " WHERE ",
      filters
    ])
  end

  @doc """
  Returns a DELETE for the `filters` returning the given `returning`.
  """
  @spec delete(
          prefix :: String.t(),
          table :: String.t(),
          filters :: [atom],
          returning :: [atom]
        ) :: String.t()
  def delete(prefix, table, filters, returning) do
    {filters, _} =
      intersperse_reduce(filters, " AND ", 1, fn field, acc ->
        {[quote_name(field), " = ?", Integer.to_string(acc)], acc + 1}
      end)

    IO.iodata_to_binary([
      "DELETE FROM ",
      quote_table(prefix, table),
      returning(returning, "DELETED"),
      " WHERE ",
      filters
    ])
  end
end
