defmodule MssqlEcto.Connection.Query do
  alias Ecto.Query
  alias Query.{BooleanExpr, JoinExpr, QueryExpr}
  alias MssqlEcto.Connection.Query.Expression
  import MssqlEcto.Connection.Helper

  def all(query) do
    sources = create_names(query)
    {select_distinct, order_by_distinct} = distinct(query.distinct, sources, query)

    select = select(query, select_distinct, sources)
    from = from(query, sources)
    join = join(query, sources)
    where = where(query, sources)
    group_by = group_by(query, sources)
    having = having(query, sources)
    window = window(query, sources)
    combinations = combinations(query)
    order_by = order_by(query, order_by_distinct, sources)
    offset = offset(query, sources)
    lock = lock(query.lock)

    [
      select,
      from,
      join,
      where,
      group_by,
      having,
      window,
      combinations,
      order_by,
      offset | lock
    ]
  end

  def update_all(%{from: %{source: source}} = query, prefix) do
    sources = create_names(query)
    {from, name} = get_source(query, sources, 0, source)
    from = prefix_name(from, query)

    prefix = prefix || ["UPDATE ", name | " SET "]
    table_alias = [" FROM ", from, " AS ", name]

    fields = update_fields(query, sources)
    join = join(query, sources)
    where = where(query, sources)

    [
      prefix,
      fields,
      output(query, sources, "INSERTED"),
      table_alias,
      join,
      where
    ]
  end

  def delete_all(%{from: from} = query) do
    sources = create_names(query)
    {from, name} = get_source(query, sources, 0, from)

    join = join(query, sources)
    where = where(query, sources)

    [
      "DELETE ",
      name,
      output(query, sources, "DELETED"),
      " FROM ",
      from,
      " AS ",
      name,
      join,
      where
    ]
  end

  def insert_as({%{sources: sources}, _, _}) do
    {_expr, name, _schema} = create_name(sources, 0)
    [" AS " | name]
  end

  def insert_as({_, _, _}) do
    []
  end

  def on_conflict({:raise, _, []}, _header),
    do: []

  def on_conflict({:nothing, _, targets}, _header),
    do: [" ON CONFLICT ", conflict_target(targets) | "DO NOTHING"]

  def on_conflict({fields, _, targets}, _header) when is_list(fields),
    do: [" ON CONFLICT ", conflict_target(targets), "DO " | replace(fields)]

  def on_conflict({query, _, targets}, _header),
    do: [" ON CONFLICT ", conflict_target(targets), "DO " | update_all(query, "UPDATE SET ")]

  defp conflict_target({:constraint, constraint}),
    do: ["ON CONSTRAINT ", quote_name(constraint), ?\s]

  defp conflict_target({:unsafe_fragment, fragment}),
    do: [fragment, ?\s]

  defp conflict_target([]),
    do: []

  defp conflict_target(targets),
    do: [?(, intersperse_map(targets, ?,, &quote_name/1), ?), ?\s]

  defp replace(fields) do
    [
      "UPDATE SET "
      | intersperse_map(fields, ?,, fn field ->
          quoted = quote_name(field)
          [quoted, " = ", "EXCLUDED." | quoted]
        end)
    ]
  end

  def insert_all(rows, counter) do
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

      {%Query{} = query, params_counter}, counter ->
        {[?(, all(query), ?)], counter + params_counter}

      _, counter ->
        {[??], counter + 1}
    end)
  end

  ## Query generation

  defp select(%{select: %{fields: fields}} = query, select_distinct, sources) do
    top = top(query, sources)
    ["SELECT", top, select_distinct, ?\s | select_fields(fields, sources, query)]
  end

  defp select_fields([], _sources, _query),
    do: "'TRUE'"

  defp select_fields(fields, sources, query) do
    intersperse_map(fields, ", ", fn
      {key, value} ->
        [Expression.expr(value, sources, query), " AS " | quote_name(key)]

      value ->
        Expression.expr(value, sources, query)
    end)
  end

  defp distinct(nil, _, _), do: {[], []}
  defp distinct(%QueryExpr{expr: []}, _, _), do: {[], []}
  defp distinct(%QueryExpr{expr: true}, _, _), do: {" DISTINCT", []}
  defp distinct(%QueryExpr{expr: false}, _, _), do: {[], []}

  defp distinct(%QueryExpr{expr: exprs}, sources, query) do
    {[
       " DISTINCT ON (",
       intersperse_map(exprs, ", ", fn {_, expr} -> Expression.expr(expr, sources, query) end),
       ?)
     ], exprs}
  end

  defp from(%{from: %{hints: [_ | _]}} = query, _sources) do
    error!(query, "table hints are not implemented")
  end

  defp from(%{from: %{source: source}, prefix: prefix} = query, sources) do
    {from, name} = get_source(query, sources, 0, source)
    [" FROM ", add_prefix(prefix, from), " AS " | name]
  end

  defp update_fields(%{updates: updates} = query, sources) do
    for(
      %{expr: expr} <- updates,
      {op, kw} <- expr,
      {key, value} <- kw,
      do: update_op(op, key, value, sources, query)
    )
    |> Enum.intersperse(", ")
  end

  defp update_op(:set, key, value, sources, query) do
    [quote_name(key), " = " | Expression.expr(value, sources, query)]
  end

  defp update_op(:inc, key, value, sources, query) do
    [
      quote_name(key),
      " = ",
      quote_qualified_name(key, sources, 0),
      " + "
      | Expression.expr(value, sources, query)
    ]
  end

  defp update_op(:push, key, value, sources, query) do
    [
      quote_name(key),
      " = array_append(",
      quote_qualified_name(key, sources, 0),
      ", ",
      Expression.expr(value, sources, query),
      ?)
    ]
  end

  defp update_op(:pull, key, value, sources, query) do
    [
      quote_name(key),
      " = array_remove(",
      quote_qualified_name(key, sources, 0),
      ", ",
      Expression.expr(value, sources, query),
      ?)
    ]
  end

  defp update_op(command, _key, _value, _sources, query) do
    error!(query, "#{inspect(command)} not implemented for MSSQL")
  end

  defp join(%{joins: []}, _sources), do: []

  defp join(%{joins: joins} = query, sources) do
    [
      ?\s
      | intersperse_map(joins, ?\s, fn
          %JoinExpr{
            on: %QueryExpr{expr: expr},
            qual: qual,
            ix: ix,
            source: source,
            hints: hints
          } ->
            if hints != [] do
              error!(query, "table hints are not implemented")
            end

            {join, name} = get_source(query, sources, ix, source)

            prefix = query.prefix

            if is_nil(prefix) do
              [join_qual(qual), join, " AS ", name | join_on(qual, expr, sources, query)]
            else
              prefix = quote_name(query.prefix)

              [
                join_qual(qual),
                prefix,
                ".",
                join,
                " AS ",
                name | join_on(qual, expr, sources, query)
              ]
            end
        end)
    ]
  end

  defp prefix_name(name, %{prefix: nil}), do: [name]

  defp prefix_name(name, %{prefix: prefix}) do
    prefix = quote_name(prefix)
    [prefix, ".", name]
  end

  defp join_on(_qual, expr, sources, query),
    do: [" ON ", Expression.paren_expr(expr, sources, query)]

  defp join_qual(:inner), do: "INNER JOIN "
  defp join_qual(:inner_lateral), do: "INNER JOIN LATERAL "
  defp join_qual(:left), do: "LEFT OUTER JOIN "
  defp join_qual(:left_lateral), do: "LEFT OUTER JOIN LATERAL "
  defp join_qual(:right), do: "RIGHT OUTER JOIN "
  defp join_qual(:full), do: "FULL OUTER JOIN "
  defp join_qual(:cross), do: "CROSS JOIN "

  defp where(%{wheres: wheres} = query, sources) do
    boolean(" WHERE ", wheres, sources, query)
  end

  defp having(%{havings: havings} = query, sources) do
    boolean(" HAVING ", havings, sources, query)
  end

  defp group_by(%{group_bys: []}, _sources), do: []

  defp group_by(%{group_bys: group_bys} = query, sources) do
    [
      " GROUP BY "
      | intersperse_map(group_bys, ", ", fn
          %QueryExpr{expr: expr} ->
            intersperse_map(expr, ", ", &Expression.expr(&1, sources, query))
        end)
    ]
  end

  defp window(%{windows: []}, _sources), do: []

  defp window(%{windows: windows} = query, sources) do
    [
      " WINDOW "
      | intersperse_map(windows, ", ", fn {name, %{expr: kw}} ->
          [quote_name(name), " AS " | Expression.window_exprs(kw, sources, query)]
        end)
    ]
  end

  defp order_by(%{order_bys: []}, _distinct, _sources), do: []

  defp order_by(%{order_bys: order_bys} = query, distinct, sources) do
    order_bys = Enum.flat_map(order_bys, & &1.expr)

    [
      " ORDER BY "
      | intersperse_map(
          distinct ++ order_bys,
          ", ",
          &Expression.order_by_expr(&1, sources, query)
        )
    ]
  end

  def top(%Query{offset: nil, limit: %QueryExpr{expr: expr}} = query, sources) do
    [" TOP ", Expression.expr(expr, sources, query)]
  end

  def top(_, _) do
    []
  end

  def offset(%Query{offset: nil, limit: nil}, _sources), do: []

  def offset(
        %Query{offset: nil, limit: %QueryExpr{expr: _expr}} = _query,
        _sources
      ) do
    []
  end

  def offset(
        %Query{
          offset: %QueryExpr{expr: offset_expr},
          limit: %QueryExpr{expr: limit_expr}
        } = query,
        sources
      ) do
    [
      " OFFSET ",
      Expression.expr(offset_expr, sources, query),
      " ROWS FETCH NEXT ",
      Expression.expr(limit_expr, sources, query),
      " ROWS ONLY"
    ]
  end

  def offset(%Query{offset: %QueryExpr{expr: expr}} = query, sources) do
    [" OFFSET ", Expression.expr(expr, sources, query), " ROWS"]
  end

  defp combinations(%{combinations: combinations}) do
    Enum.map(combinations, fn
      {:union, query} -> [" UNION (", all(query), ")"]
      {:union_all, query} -> [" UNION ALL (", all(query), ")"]
      {:except, query} -> [" EXCEPT (", all(query), ")"]
      {:except_all, query} -> [" EXCEPT ALL (", all(query), ")"]
      {:intersect, query} -> [" INTERSECT (", all(query), ")"]
      {:intersect_all, query} -> [" INTERSECT ALL (", all(query), ")"]
    end)
  end

  defp lock(nil), do: []
  defp lock(lock_clause), do: [?\s | lock_clause]

  defp boolean(_name, [], _sources, _query), do: []

  defp boolean(name, [%{expr: expr, op: op} | query_exprs], sources, query) do
    [
      name
      | Enum.reduce(query_exprs, {op, Expression.paren_expr(expr, sources, query)}, fn
          %BooleanExpr{expr: expr, op: op}, {op, acc} ->
            {op, [acc, operator_to_boolean(op), Expression.paren_expr(expr, sources, query)]}

          %BooleanExpr{expr: expr, op: op}, {_, acc} ->
            {op,
             [?(, acc, ?), operator_to_boolean(op), Expression.paren_expr(expr, sources, query)]}
        end)
        |> elem(1)
    ]
  end

  defp operator_to_boolean(:and), do: " AND "
  defp operator_to_boolean(:or), do: " OR "

  def output(%Ecto.Query{select: nil}, _sources, _), do: []

  def output(
        %Ecto.Query{select: %{fields: fields}} = query,
        _sources,
        operation
      ),
      do: [
        " OUTPUT "
        | select_fields(fields, {{nil, operation, nil}}, query)
      ]

  def output([], _), do: []

  def output(returning, operation),
    do: [
      " OUTPUT "
      | Enum.map_join(returning, ", ", fn column ->
          [operation, ?. | quote_name(column)]
        end)
    ]

  defp create_names(%{sources: sources}) do
    create_names(sources, 0, tuple_size(sources))
    |> List.to_tuple()
  end

  defp create_names(sources, pos, limit) when pos < limit do
    [create_name(sources, pos) | create_names(sources, pos + 1, limit)]
  end

  defp create_names(_sources, pos, pos) do
    []
  end

  defp create_name(sources, pos) do
    case elem(sources, pos) do
      {:fragment, _, _} ->
        {nil, [?f | Integer.to_string(pos)], nil}

      {table, schema, prefix} ->
        name = [create_alias(table) | Integer.to_string(pos)]
        {quote_table(prefix, table), name, schema}

      %Ecto.SubQuery{} ->
        {nil, [?s | Integer.to_string(pos)], nil}
    end
  end

  defp create_alias(<<first, _rest::binary>>) when first in ?a..?z when first in ?A..?Z do
    <<first>>
  end

  defp create_alias(_) do
    "t"
  end
end
