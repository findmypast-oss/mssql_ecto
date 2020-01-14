defmodule MssqlEcto.Connection.Helper do
  @moduledoc false

  alias MssqlEcto.Connection.Query.Expression
  require Logger

  def get_source(query, sources, ix, source) do
    {expr, name, _schema} = elem(sources, ix)
    {expr || Expression.expr(source, sources, query), name}
  end

  def add_prefix(nil, name) do
    name
  end

  def add_prefix(prefix, name) do
    [quote_name(prefix), ".", name]
  end

  def quote_qualified_name(name, sources, ix) do
    {_, source, _} = elem(sources, ix)
    [source, ?. | quote_name(name)]
  end

  def quote_name(name, quoter \\ ?")
  def quote_name(nil, _), do: []

  def quote_name(names, quoter) when is_list(names) do
    names
    |> Enum.filter(&(not is_nil(&1)))
    |> intersperse_map(?., &quote_name(&1, nil))
    |> wrap_in(quoter)
  end

  def quote_name(name, quoter) when is_atom(name) do
    quote_name(Atom.to_string(name), quoter)
  end

  def quote_name(name, quoter) do
    if String.contains?(name, "\"") do
      error!(nil, "bad name #{inspect(name)}")
    end

    wrap_in(name, quoter)
  end

  def wrap_in(value, nil), do: value

  def wrap_in(value, {left_wrapper, right_wrapper}) do
    [left_wrapper, value, right_wrapper]
  end

  def wrap_in(value, wrapper) do
    [wrapper, value, wrapper]
  end

  def quote_table(nil, name), do: quote_table(name)
  def quote_table(prefix, name), do: [quote_table(prefix), ?., quote_table(name)]

  def quote_table(name) when is_atom(name),
    do: quote_table(Atom.to_string(name))

  def quote_table(name) do
    if String.contains?(name, "\"") do
      error!(nil, "bad table name #{inspect(name)}")
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

  def ecto_to_db({:array, t}), do: [ecto_to_db(t), ?[, ?]]
  def ecto_to_db(:id), do: "int identity(1,1)"
  def ecto_to_db(:serial), do: "int identity(1,1)"
  def ecto_to_db(:bigserial), do: "bigint identity(1,1)"
  def ecto_to_db(:binary_id), do: "char(36)"
  def ecto_to_db(:uuid), do: "char(36)"
  def ecto_to_db(:string), do: "nvarchar"
  def ecto_to_db(:binary), do: "nvarchar(4000)"
  def ecto_to_db(:integer), do: "int"
  def ecto_to_db(:boolean), do: "bit"
  def ecto_to_db(:map), do: "nvarchar(4000)"
  def ecto_to_db({:map, _}), do: "nvarchar(4000)"
  def ecto_to_db(:utc_datetime), do: "datetime2"
  def ecto_to_db(:utc_datetime_usec), do: "datetime2"
  def ecto_to_db(:naive_datetime), do: "datetime2"
  def ecto_to_db(:naive_datetime_usec), do: "datetime2"
  def ecto_to_db(:timestamp), do: "datetime2"

  def ecto_to_db(:bigint), do: "bigint"
  def ecto_to_db(:decimal), do: "decimal"
  def ecto_to_db(:float), do: "float"
  def ecto_to_db(:date), do: "date"
  def ecto_to_db(:text), do: "text"
  def ecto_to_db(:numeric), do: "numeric"

  def ecto_to_db(other) do
    Logger.warn("type not explicitly handled: #{other}")
    Atom.to_string(other)
  end

  def error!(nil, message) do
    raise ArgumentError, message
  end

  def error!(query, message) do
    raise Ecto.QueryError, query: query, message: message
  end
end
