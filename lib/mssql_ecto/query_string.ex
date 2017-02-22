defmodule MssqlEcto.QueryString do

  alias Ecto.Query
  alias Ecto.Query.{BooleanExpr, JoinExpr, QueryExpr}
  alias MssqlEcto.Connection
  alias MssqlEcto.Helpers

  binary_ops =
    [==: " = ", !=: " != ", <=: " <= ", >=: " >= ", <: " < ", >: " > ",
     and: " AND ", or: " OR ", ilike: " ILIKE ", like: " LIKE "]

  @binary_ops Keyword.keys(binary_ops)

  Enum.map(binary_ops, fn {op, str} ->
    def handle_call(unquote(op), 2), do: {:binary_op, unquote(str)}
  end)

  def handle_call(fun, _arity), do: {:fun, Atom.to_string(fun)}

  def select(%Query{select: %{fields: fields}} = query, select_distinct, sources) do
    ["SELECT", select_distinct, ?\s | select_fields(fields, sources, query)]
  end

  def select_fields([], _sources, _query),
    do: "TRUE"
  def select_fields(fields, sources, query) do
    Helpers.intersperse_map(fields, ", ", fn
      {key, value} ->
        [expr(value, sources, query), " AS " | Helpers.quote_name(key)]
      value ->
        expr(value, sources, query)
    end)
  end

  def distinct(nil, _, _), do: {[], []}
  def distinct(%QueryExpr{expr: []}, _, _), do: {[], []}
  def distinct(%QueryExpr{expr: true}, _, _), do: {" DISTINCT", []}
  def distinct(%QueryExpr{expr: false}, _, _), do: {[], []}
  def distinct(%QueryExpr{expr: exprs}, sources, query) do
    {[" DISTINCT ON (",
      Helpers.intersperse_map(exprs, ", ", fn {_, expr} -> expr(expr, sources, query) end), ?)],
     exprs}
  end

  def from(%{from: from} = query, sources) do
    {from, name} = Helpers.get_source(query, sources, 0, from)
    [" FROM ", from, " AS " | name]
  end

  def update_fields(%Query{updates: updates} = query, sources) do
    for(%{expr: expr} <- updates,
        {op, kw} <- expr,
        {key, value} <- kw,
        do: update_op(op, key, value, sources, query)) |> Enum.intersperse(", ")
  end

  def update_op(:set, key, value, sources, query) do
    [Helpers.quote_name(key), " = " | expr(value, sources, query)]
  end

  def update_op(:inc, key, value, sources, query) do
    [Helpers.quote_name(key), " = ", Helpers.quote_qualified_name(key, sources, 0), " + " |
     expr(value, sources, query)]
  end

  def update_op(:push, key, value, sources, query) do
    [Helpers.quote_name(key), " = array_append(", Helpers.quote_qualified_name(key, sources, 0),
     ", ", expr(value, sources, query), ?)]
  end

  def update_op(:pull, key, value, sources, query) do
    [Helpers.quote_name(key), " = array_remove(", Helpers.quote_qualified_name(key, sources, 0),
     ", ", expr(value, sources, query), ?)]
  end

  def update_op(command, _key, _value, _sources, query) do
    Helpers.error!(query, "Unknown update operation #{inspect command} for PostgreSQL")
  end

  def using_join(%Query{joins: []}, _kind, _prefix, _sources), do: {[], []}
  def using_join(%Query{joins: joins} = query, kind, prefix, sources) do
    froms =
      Helpers.intersperse_map(joins, ", ", fn
        %JoinExpr{qual: :inner, ix: ix, source: source} ->
          {join, name} = Helpers.get_source(query, sources, ix, source)
          [join, " AS " | name]
        %JoinExpr{qual: qual} ->
          Helpers.error!(query, "PostgreSQL supports only inner joins on #{kind}, got: `#{qual}`")
      end)

    wheres =
      for %JoinExpr{on: %QueryExpr{expr: value} = expr} <- joins,
          value != true,
          do: expr |> Map.put(:__struct__, BooleanExpr) |> Map.put(:op, :and)

    {[?\s, prefix, ?\s | froms], wheres}
  end

  def join(%Query{joins: []}, _sources), do: []
  def join(%Query{joins: joins} = query, sources) do
    [?\s | Helpers.intersperse_map(joins, ?\s, fn
      %JoinExpr{on: %QueryExpr{expr: expr}, qual: qual, ix: ix, source: source} ->
        {join, name} = Helpers.get_source(query, sources, ix, source)
        [join_qual(qual), join, " AS ", name, " ON " | expr(expr, sources, query)]
    end)]
  end

  def join_qual(:inner), do: "INNER JOIN "
  def join_qual(:inner_lateral), do: "INNER JOIN LATERAL "
  def join_qual(:left),  do: "LEFT OUTER JOIN "
  def join_qual(:left_lateral),  do: "LEFT OUTER JOIN LATERAL "
  def join_qual(:right), do: "RIGHT OUTER JOIN "
  def join_qual(:full),  do: "FULL OUTER JOIN "
  def join_qual(:cross), do: "CROSS JOIN "

  def where(%Query{wheres: wheres} = query, sources) do
    boolean(" WHERE ", wheres, sources, query)
  end

  def having(%Query{havings: havings} = query, sources) do
    boolean(" HAVING ", havings, sources, query)
  end

  def group_by(%Query{group_bys: []}, _sources), do: []
  def group_by(%Query{group_bys: group_bys} = query, sources) do
    [" GROUP BY " |
     Helpers.intersperse_map(group_bys, ", ", fn
       %QueryExpr{expr: expr} ->
         Helpers.intersperse_map(expr, ", ", &expr(&1, sources, query))
     end)]
  end

  def order_by(%Query{order_bys: []}, _distinct, _sources), do: []
  def order_by(%Query{order_bys: order_bys} = query, distinct, sources) do
    order_bys = Enum.flat_map(order_bys, & &1.expr)
    [" ORDER BY " |
     Helpers.intersperse_map(distinct ++ order_bys, ", ", &order_by_expr(&1, sources, query))]
  end

  def order_by_expr({dir, expr}, sources, query) do
    str = expr(expr, sources, query)
    case dir do
      :asc  -> str
      :desc -> [str | " DESC"]
    end
  end

  def limit(%Query{limit: nil}, _sources), do: []
  def limit(%Query{limit: %QueryExpr{expr: expr}} = query, sources) do
    [" LIMIT " | expr(expr, sources, query)]
  end

  def offset(%Query{offset: nil}, _sources), do: []
  def offset(%Query{offset: %QueryExpr{expr: expr}} = query, sources) do
    [" OFFSET " | expr(expr, sources, query)]
  end

  def lock(nil), do: []
  def lock(lock_clause), do: [?\s | lock_clause]

  def boolean(_name, [], _sources, _query), do: []
  def boolean(name, [%{expr: expr, op: op} | query_exprs], sources, query) do
    [name |
     Enum.reduce(query_exprs, {op, paren_expr(expr, sources, query)}, fn
       %BooleanExpr{expr: expr, op: op}, {op, acc} ->
         {op, [acc, operator_to_boolean(op), paren_expr(expr, sources, query)]}
       %BooleanExpr{expr: expr, op: op}, {_, acc} ->
         {op, [?(, acc, ?), operator_to_boolean(op), paren_expr(expr, sources, query)]}
     end) |> elem(1)]
  end

  def operator_to_boolean(:and), do: " AND "
  def operator_to_boolean(:or), do: " OR "

  def paren_expr(expr, sources, query) do
    [?(, expr(expr, sources, query), ?)]
  end

  def expr({:^, [], [ix]}, _sources, _query) do
    [?$ | Integer.to_string(ix + 1)]
  end

  def expr({{:., _, [{:&, _, [idx]}, field]}, _, []}, sources, _query) when is_atom(field) do
    Helpers.quote_qualified_name(field, sources, idx)
  end

  def expr({:&, _, [idx, fields, _counter]}, sources, query) do
    {_, name, schema} = elem(sources, idx)
    if is_nil(schema) and is_nil(fields) do
      Helpers.error!(query, "PostgreSQL requires a schema module when using selector " <>
        "#{inspect name} but none was given. " <>
        "Please specify a schema or specify exactly which fields from " <>
        "#{inspect name} you desire")
    end
    Helpers.intersperse_map(fields, ", ", &[name, ?. | Helpers.quote_name(&1)])
  end

  def expr({:in, _, [_left, []]}, _sources, _query) do
    "false"
  end

  def expr({:in, _, [left, right]}, sources, query) when is_list(right) do
    args = Helpers.intersperse_map(right, ?,, &expr(&1, sources, query))
    [expr(left, sources, query), " IN (", args, ?)]
  end

  def expr({:in, _, [left, {:^, _, [ix, _]}]}, sources, query) do
    [expr(left, sources, query), " = ANY($", Integer.to_string(ix + 1), ?)]
  end

  def expr({:in, _, [left, right]}, sources, query) do
    [expr(left, sources, query), " = ANY(", expr(right, sources, query), ?)]
  end

  def expr({:is_nil, _, [arg]}, sources, query) do
    [expr(arg, sources, query) | " IS NULL"]
  end

  def expr({:not, _, [expr]}, sources, query) do
    ["NOT (", expr(expr, sources, query), ?)]
  end

  def expr(%Ecto.SubQuery{query: query, fields: fields}, _sources, _query) do
    query.select.fields |> put_in(fields) |> Connection.all()
  end

  def expr({:fragment, _, [kw]}, _sources, query) when is_list(kw) or tuple_size(kw) == 3 do
    Helpers.error!(query, "PostgreSQL adapter does not support keyword or interpolated fragments")
  end

  def expr({:fragment, _, parts}, sources, query) do
    Enum.map(parts, fn
      {:raw, part}  -> part
      {:expr, expr} -> expr(expr, sources, query)
    end)
  end

  def expr({:datetime_add, _, [datetime, count, interval]}, sources, query) do
    [?(, expr(datetime, sources, query), "::timestamp + ",
     interval(count, interval, sources, query) | ")::timestamp"]
  end

  def expr({:date_add, _, [date, count, interval]}, sources, query) do
    [?(, expr(date, sources, query), "::date + ",
     interval(count, interval, sources, query) | ")::date"]
  end

  def expr({fun, _, args}, sources, query) when is_atom(fun) and is_list(args) do
    {modifier, args} =
      case args do
        [rest, :distinct] -> {"DISTINCT ", [rest]}
        _ -> {[], args}
      end

    case handle_call(fun, length(args)) do
      {:binary_op, op} ->
        [left, right] = args
        [op_to_binary(left, sources, query), op | op_to_binary(right, sources, query)]
      {:fun, fun} ->
        [fun, ?(, modifier, Helpers.intersperse_map(args, ", ", &expr(&1, sources, query)), ?)]
    end
  end

  def expr(list, sources, query) when is_list(list) do
    ["ARRAY[", Helpers.intersperse_map(list, ?,, &expr(&1, sources, query)), ?]]
  end

  def expr(%Decimal{} = decimal, _sources, _query) do
    Decimal.to_string(decimal, :normal)
  end

  def expr(%Ecto.Query.Tagged{value: binary, type: :binary}, _sources, _query)
      when is_binary(binary) do
    ["'\\x", Base.encode16(binary, case: :lower) | "'::bytea"]
  end

  def expr(%Ecto.Query.Tagged{value: other, type: type}, sources, query) do
    [expr(other, sources, query), ?:, ?: | Helpers.ecto_to_db(type)]
  end

  def expr(nil, _sources, _query),   do: "NULL"
  def expr(true, _sources, _query),  do: "TRUE"
  def expr(false, _sources, _query), do: "FALSE"

  def expr(literal, _sources, _query) when is_binary(literal) do
    [?\', Helpers.escape_string(literal), ?\']
  end

  def expr(literal, _sources, _query) when is_integer(literal) do
    Integer.to_string(literal)
  end

  def expr(literal, _sources, _query) when is_float(literal) do
    [Float.to_string(literal) | "::float"]
  end

  def interval(count, interval, _sources, _query) when is_integer(count) do
    ["interval '", String.Chars.Integer.to_string(count), ?\s, interval, ?\']
  end

  def interval(count, interval, _sources, _query) when is_float(count) do
    count = :erlang.float_to_binary(count, [:compact, decimals: 16])
    ["interval '", count, ?\s, interval, ?\']
  end

  def interval(count, interval, sources, query) do
    [?(, expr(count, sources, query), "::numeric * ",
     interval(1, interval, sources, query), ?)]
  end

  def op_to_binary({op, _, [_, _]} = expr, sources, query) when op in @binary_ops do
    paren_expr(expr, sources, query)
  end

  def op_to_binary(expr, sources, query) do
    expr(expr, sources, query)
  end

  def returning(%Query{select: nil}, _sources),
    do: []
  def returning(%Query{select: %{fields: fields}} = query, sources),
    do: [" RETURNING " | select_fields(fields, sources, query)]

  def returning([]),
    do: []
  def returning(returning),
    do: [" RETURNING " | Helpers.intersperse_map(returning, ", ", &Helpers.quote_name/1)]

  def create_names(%{prefix: prefix, sources: sources}) do
    create_names(prefix, sources, 0, tuple_size(sources)) |> List.to_tuple()
  end

  def create_names(prefix, sources, pos, limit) when pos < limit do
    current =
      case elem(sources, pos) do
        {table, schema} ->
          name = [String.first(table) | Integer.to_string(pos)]
          {Helpers.quote_table(prefix, table), name, schema}
        {:fragment, _, _} ->
          {nil, [?f | Integer.to_string(pos)], nil}
        %Ecto.SubQuery{} ->
          {nil, [?s | Integer.to_string(pos)], nil}
      end
    [current | create_names(prefix, sources, pos + 1, limit)]
  end

  def create_names(_prefix, _sources, pos, pos) do
    []
  end
end
