defmodule MssqlEcto.Connection.Query.Expression do
  alias MssqlEcto.Connection.Query
  import MssqlEcto.Connection.Helper

  binary_ops = [
    ==: " = ",
    !=: " != ",
    <=: " <= ",
    >=: " >= ",
    <: " < ",
    >: " > ",
    +: " + ",
    -: " - ",
    *: " * ",
    /: " / ",
    and: " AND ",
    or: " OR ",
    ilike: " ILIKE ",
    like: " LIKE "
  ]

  @binary_ops Keyword.keys(binary_ops)

  Enum.map(binary_ops, fn {op, str} ->
    defp handle_call(unquote(op), 2), do: {:binary_op, unquote(str)}
  end)

  defp handle_call(fun, _arity), do: {:fun, Atom.to_string(fun)}

  defp op_to_binary({op, _, [_, _]} = expr, sources, query) when op in @binary_ops do
    paren_expr(expr, sources, query)
  end

  defp op_to_binary(expr, sources, query) do
    expr(expr, sources, query)
  end

  def paren_expr(false, _sources, _query), do: "(0=1)"
  def paren_expr(true, _sources, _query), do: "(1=1)"

  def paren_expr(expr, sources, query) do
    [?(, expr(expr, sources, query), ?)]
  end

  def expr(%Ecto.SubQuery{query: query}, _sources, _query) do
    [?(, Query.all(query), ?)]
  end

  def expr({:^, [], [_]}, _sources, _query) do
    [??]
  end

  def expr({{:., _, [{:&, _, [idx]}, field]}, _, []}, sources, _query) when is_atom(field) do
    quote_qualified_name(field, sources, idx)
  end

  def expr({:&, _, [idx]}, sources, query) do
    {_source, name, _schema} = elem(sources, idx)

    error!(
      query,
      "Microsoft SQL Server requires a schema module when using selector " <>
        "#{inspect(name)} but none was given. " <>
        "Please specify a schema or specify exactly which fields from " <>
        "#{inspect(name)} you desire"
    )
  end

  def expr({:&, _, [idx, fields, _counter]}, sources, query) do
    {_, name, schema} = elem(sources, idx)

    if is_nil(schema) and is_nil(fields) do
      error!(
        query,
        "Microsoft SQL Server requires a schema module when using selector " <>
          "#{inspect(name)} but none was given. " <>
          "Please specify a schema or specify exactly which fields from " <>
          "#{inspect(name)} you desire"
      )
    end

    intersperse_map(fields, ", ", &[name, ?. | quote_name(&1)])
  end

  def expr({:in, _, [_left, []]}, _sources, _query) do
    "0=1"
  end

  def expr({:in, _, [left, right]}, sources, query) when is_list(right) do
    args = intersperse_map(right, ?,, &expr(&1, sources, query))
    [expr(left, sources, query), " IN (", args, ?)]
  end

  def expr({:in, _, [_, {:^, _, [_, 0]}]}, _sources, _query) do
    "0=1"
  end

  def expr({:in, _, [left, {:^, _, [_ix, length]}]}, sources, query) do
    args =
      Enum.map(1..length, fn _ -> [??] end)
      |> Enum.intersperse(?,)

    [expr(left, sources, query), " IN (", args, ?)]
  end

  def expr({:in, _, [left, right]}, sources, query) do
    [expr(left, sources, query), " = ANY(", expr(right, sources, query), ?)]
  end

  def expr({:is_nil, _, [arg]}, sources, query) do
    [expr(arg, sources, query) | " IS NULL"]
  end

  def expr({:not, _, [expr]}, sources, query) do
    case expr do
      {fun, _, _} when fun in @binary_ops ->
        ["NOT (", expr(expr, sources, query), ?)]

      _ ->
        ["~(", expr(expr, sources, query), ?)]
    end
  end

  def expr({:fragment, _, [kw]}, _sources, query)
      when is_list(kw) or tuple_size(kw) == 3 do
    error!(
      query,
      "Microsoft SQL Server adapter does not support keyword or interpolated fragments"
    )
  end

  def expr({:fragment, _, parts}, sources, query) do
    Enum.map(parts, fn
      {:raw, part} -> part
      {:expr, expr} -> expr(expr, sources, query)
    end)
    |> parens_for_select()
  end

  # TODO timestamp and date types? is this correct
  def expr({:datetime_add, _, [datetime, count, interval]}, sources, query) do
    [
      expr(datetime, sources, query),
      "::timestamp + ",
      interval(count, interval, sources, query)
    ]
  end

  def expr({:date_add, _, [date, count, interval]}, sources, query) do
    [
      ?(,
      expr(date, sources, query),
      "::date + ",
      interval(count, interval, sources, query) | ")::date"
    ]
  end

  def expr({:filter, _, [agg, filter]}, sources, query) do
    aggregate = expr(agg, sources, query)
    [aggregate, " FILTER (WHERE ", expr(filter, sources, query), ?)]
  end

  def expr({:over, _, [agg, name]}, sources, query) when is_atom(name) do
    aggregate = expr(agg, sources, query)
    [aggregate, " OVER " | quote_name(name)]
  end

  def expr({:over, _, [agg, kw]}, sources, query) do
    aggregate = expr(agg, sources, query)
    [aggregate, " OVER ", window_exprs(kw, sources, query)]
  end

  def expr({:{}, _, elems}, sources, query) do
    [?(, intersperse_map(elems, ?,, &expr(&1, sources, query)), ?)]
  end

  def expr({:count, _, []}, _sources, _query), do: "count(*)"

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
        [fun, ?(, modifier, intersperse_map(args, ", ", &expr(&1, sources, query)), ?)]
    end
  end

  def expr(list, sources, query) when is_list(list) do
    ["ARRAY[", intersperse_map(list, ?,, &expr(&1, sources, query)), ?]]
  end

  def expr(%Decimal{} = decimal, _sources, _query) do
    Decimal.to_string(decimal, :normal)
  end

  def expr(%Ecto.Query.Tagged{value: binary, type: :binary}, _sources, _query)
      when is_binary(binary) do
    ["0x", Base.encode16(binary, case: :lower)]
  end

  def expr(%Ecto.Query.Tagged{value: other, type: type}, sources, query) do
    ["CAST(", expr(other, sources, query), " AS ", tagged_to_db(type) | ")"]
  end

  def expr(nil, _sources, _query), do: "NULL"
  def expr(true, _sources, _query), do: "1"
  def expr(false, _sources, _query), do: "0"

  def expr(literal, _sources, _query) when is_binary(literal) do
    [?\', escape_string(literal), ?\']
  end

  def expr(literal, _sources, _query) when is_integer(literal) do
    Integer.to_string(literal)
  end

  def expr(literal, _sources, _query) when is_float(literal) do
    [Float.to_string(literal)]
  end

  defp parens_for_select([first_expr | _] = expr) do
    if is_binary(first_expr) and String.starts_with?(first_expr, ["SELECT", "select"]) do
      [?(, expr, ?)]
    else
      expr
    end
  end

  defp interval(count, interval, _sources, _query) when is_integer(count) do
    ["interval '", String.Chars.Integer.to_string(count), ?\s, interval, ?\']
  end

  defp interval(count, interval, _sources, _query) when is_float(count) do
    count = :erlang.float_to_binary(count, [:compact, decimals: 16])
    ["interval '", count, ?\s, interval, ?\']
  end

  # TODO numeric data type? Is this correct?
  defp interval(count, interval, sources, query) do
    [
      ?(,
      expr(count, sources, query),
      "::numeric * ",
      interval(1, interval, sources, query),
      ?)
    ]
  end

  defp tagged_to_db({:array, type}), do: [tagged_to_db(type), ?[, ?]]
  # Always use the largest possible type for integers
  defp tagged_to_db(:id), do: "int"
  defp tagged_to_db(:integer), do: "int"
  defp tagged_to_db(type), do: ecto_to_db(type)

  def window_exprs(kw, sources, query) do
    [?(, intersperse_map(kw, ?\s, &window_expr(&1, sources, query)), ?)]
  end

  defp window_expr({:partition_by, fields}, sources, query) do
    ["PARTITION BY " | intersperse_map(fields, ", ", &expr(&1, sources, query))]
  end

  defp window_expr({:order_by, fields}, sources, query) do
    ["ORDER BY " | intersperse_map(fields, ", ", &order_by_expr(&1, sources, query))]
  end

  defp window_expr({:frame, {:fragment, _, _} = fragment}, sources, query) do
    expr(fragment, sources, query)
  end

  def order_by_expr({dir, expr}, sources, query) do
    str = expr(expr, sources, query)

    case dir do
      :asc -> str
      :asc_nulls_last -> [str | " ASC NULLS LAST"]
      :asc_nulls_first -> [str | " ASC NULLS FIRST"]
      :desc -> [str | " DESC"]
      :desc_nulls_last -> [str | " DESC NULLS LAST"]
      :desc_nulls_first -> [str | " DESC NULLS FIRST"]
    end
  end
end
