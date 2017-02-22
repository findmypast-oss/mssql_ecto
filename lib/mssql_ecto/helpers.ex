defmodule MssqlEcto.Helpers do

  alias MssqlEcto.QueryString

  def get_source(query, sources, ix, source) do
    {expr, name, _schema} = elem(sources, ix)
    {expr || QueryString.paren_expr(source, sources, query), name}
  end

  def quote_qualified_name(name, sources, ix) do
    {_, source, _} = elem(sources, ix)
    [source, ?. | quote_name(name)]
  end

  def quote_name(name) when is_atom(name) do
    quote_name(Atom.to_string(name))
  end
  def quote_name(name) do
    if String.contains?(name, "\"") do
      error!(nil, "bad field name #{inspect name}")
    end
    [?", name, ?"]
  end

  def quote_table(nil, name),    do: quote_table(name)
  def quote_table(prefix, name), do: [quote_table(prefix), ?., quote_table(name)]

  def quote_table(name) when is_atom(name),
    do: quote_table(Atom.to_string(name))
  def quote_table(name) do
    if String.contains?(name, "\"") do
      error!(nil, "bad table name #{inspect name}")
    end
    [?", name, ?"]
  end

  def single_quote(value), do: [?', escape_string(value), ?']

  def intersperse_map(list, separator, mapper, acc \\ [])
  def intersperse_map([], _separator, _mapper, acc),
    do: acc
  def intersperse_map([elem], _separator, mapper, acc),
    do: [acc | mapper.(elem)]
  def intersperse_map([elem | rest], separator, mapper, acc),
    do: intersperse_map(rest, separator, mapper, [acc, mapper.(elem), separator])

  def intersperse_reduce(list, separator, user_acc, reducer, acc \\ [])
  def intersperse_reduce([], _separator, user_acc, _reducer, acc),
    do: {acc, user_acc}
  def intersperse_reduce([elem], _separator, user_acc, reducer, acc) do
    {elem, user_acc} = reducer.(elem, user_acc)
    {[acc | elem], user_acc}
  end
  def intersperse_reduce([elem | rest], separator, user_acc, reducer, acc) do
    {elem, user_acc} = reducer.(elem, user_acc)
    intersperse_reduce(rest, separator, user_acc, reducer, [acc, elem, separator])
  end

  def if_do(condition, value) do
    if condition, do: value, else: []
  end

  def escape_string(value) when is_binary(value) do
    :binary.replace(value, "'", "''", [:global])
  end

  def ecto_to_db({:array, t}),     do: [ecto_to_db(t), ?[, ?]]
  def ecto_to_db(:id),             do: "integer"
  def ecto_to_db(:binary_id),      do: "uuid"
  def ecto_to_db(:string),         do: "varchar"
  def ecto_to_db(:binary),         do: "bytea"
  def ecto_to_db(:map),            do: Application.fetch_env!(:ecto, :postgres_map_type)
  def ecto_to_db({:map, _}),       do: Application.fetch_env!(:ecto, :postgres_map_type)
  def ecto_to_db(:utc_datetime),   do: "timestamp"
  def ecto_to_db(:naive_datetime), do: "timestamp"
  def ecto_to_db(other),           do: Atom.to_string(other)

  def error!(nil, message) do
    raise ArgumentError, message
  end
  def error!(query, message) do
    raise Ecto.QueryError, query: query, message: message
  end

end
