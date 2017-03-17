defmodule MssqlEcto.Connection do

  alias MssqlEcto.QueryString
  alias Mssqlex.Query

  import MssqlEcto.Helpers

  @typedoc "The prepared query which is an SQL command"
  @type prepared :: String.t

  @typedoc "The cache query which is a DBConnection Query"
  @type cached :: map

  @doc """
  Receives options and returns `DBConnection` supervisor child
  specification.
  """
  @spec child_spec(options :: Keyword.t) :: {module, Keyword.t}
  def child_spec(opts) do
    DBConnection.child_spec(Mssqlex.Protocol, opts)
  end

  @doc """
  Prepares and executes the given query with `DBConnection`.
  """
  @spec prepare_execute(connection :: DBConnection.t, name :: String.t, prepared, params :: [term], options :: Keyword.t) ::
  {:ok, query :: map, term} | {:error, Exception.t}
  def prepare_execute(conn, name, prepared_query, params, options) do
    statement = sanitise_query(prepared_query)
    |> IO.inspect

    ordered_params = order_params(prepared_query, params)
    |> IO.inspect

    case DBConnection.prepare_execute(conn, %Query{name: name, statement: statement}, ordered_params, options) do
      {:ok, query, result} ->
        {:ok, %{query | statement: prepared_query}, process_rows(result, options)}
      {:error, %Mssqlex.Error{}} = error ->
        if is_erlang_odbc_no_data_found_bug?(error, prepared_query) do
          {:ok, %Query{name: "", statement: prepared_query}, %{num_rows: 0, rows: []}}
        else
          error
        end
      {:error, error} -> raise error
    end
  end

  @doc """
  Executes the given prepared query with `DBConnection`.
  """
  @spec execute(connection :: DBConnection.t, prepared_query :: prepared, params :: [term], options :: Keyword.t) ::
            {:ok, term} | {:error, Exception.t}
  @spec execute(connection :: DBConnection.t, prepared_query :: cached, params :: [term], options :: Keyword.t) ::
            {:ok, term} | {:error | :reset, Exception.t}
  def execute(conn, %Query{} = query, params, options) do
    ordered_params =
      query.statement
      |> IO.iodata_to_binary
      |> order_params(params)
      |> IO.inspect

    sanitised_query = sanitise_query(query.statement)
    |> IO.inspect

    query = Map.put(query, :statement, sanitised_query)

    case DBConnection.prepare_execute(conn, query, ordered_params, options) do
      {:ok, _query, result} -> {:ok, process_rows(result, options)}
      {:error, %Mssqlex.Error{}} = error ->
        if is_erlang_odbc_no_data_found_bug?(error, query.statement) do
          {:ok, %{num_rows: 0, rows: []}}
        else
          error
        end
      {:error, error} -> raise error
    end
  end
  def execute(conn, statement, params, options) do
    execute(conn, %Query{name: "", statement: statement}, params, options)
  end

  def order_params(query, params) do
    sanitised = Regex.replace(~r/(([^\\]|^))["'].*?[^\\]['"]/, IO.iodata_to_binary(query), "\\g{1}")

    ordering =
      Regex.scan(~r/\?([0-9]+)/, sanitised)
      |> Enum.map( fn [_, x] -> String.to_integer(x) end)

    if length(ordering) != length(params) do
      IO.inspect query
      IO.inspect params
      raise "\nError: number of params received (#{length(params)}) does not match expected (#{length(ordering)})"
    end

    ordered_params =
      ordering
      |> Enum.reduce([], fn ix, acc -> [Enum.at(params, ix - 1) | acc] end)
      |> Enum.reverse

    case ordered_params do
      []  -> params
      _   -> ordered_params
    end
  end

  def sanitise_query(query) do
    query
    |> IO.iodata_to_binary
    |> String.replace(~r/(\?([0-9]+))(?=(?:[^\\"']|[\\"'][^\\"']*[\\"'])*$)/, "?")
  end

  @doc """
    When a INSERT, UPDATE or DELETE query returns no data the erlang ODBC driver may return an
    erroneous "No SQL-driver information available." error
  """
  defp is_erlang_odbc_no_data_found_bug?({:error, error}, statement) do
      is_dml = statement
      |> IO.iodata_to_binary()
      |> (fn string -> String.starts_with?(string, "INSERT") || String.starts_with?(string, "DELETE") || String.starts_with?(string, "UPDATE") end).()

      is_dml and error.message == "No SQL-driver information available."
  end

  defp process_rows(result, options) do
    # IO.inspect options[:decode_mapper]
    decoder = options[:decode_mapper] || fn x -> x end
    Map.update!(result, :rows, fn row ->
      unless is_nil(row), do: Enum.map(row, decoder)
    end)
  end

  @doc """
  Returns a stream that prepares and executes the given query with
  `DBConnection`.
  """
  @spec stream(connection :: DBConnection.conn, prepared_query :: prepared, params :: [term], options :: Keyword.t) ::
            Enum.t
  def stream(_conn, _prepared, _params, _options) do
    raise("not implemented")
  end

  @doc """
  Receives the exception returned by `query/4`.
  The constraints are in the keyword list and must return the
  constraint type, like `:unique`, and the constraint name as
  a string, for example:
      [unique: "posts_title_index"]
  Must return an empty list if the error does not come
  from any constraint.
  """
  @spec to_constraints(exception :: Exception.t) :: Keyword.t
  def to_constraints(%Mssqlex.Error{} = error), do: error.constraint_violations

  ## Queries

  @doc """
  Receives a query and must return a SELECT query.
  """
  @spec all(query :: Ecto.Query.t) :: String.t
  def all(query) do
    sources = QueryString.create_names(query)
    {select_distinct, order_by_distinct} = QueryString.distinct(query.distinct, sources, query)

    from     = QueryString.from(query, sources)
    select   = QueryString.select(query, select_distinct, sources)
    join     = QueryString.join(query, sources)
    where    = QueryString.where(query, sources)
    group_by = QueryString.group_by(query, sources)
    having   = QueryString.having(query, sources)
    order_by = QueryString.order_by(query, order_by_distinct, sources)
    offset   = QueryString.offset(query, sources)
    lock     = QueryString.lock(query.lock)

    IO.iodata_to_binary([select, from, join, where, group_by, having, order_by, offset | lock])
  end

  @doc """
  Receives a query and values to update and must return an UPDATE query.
  """
  @spec update_all(query :: Ecto.Query.t) :: String.t
  def update_all(%{from: from} = query, prefix \\ nil) do
    sources = QueryString.create_names(query)
    {from, name} = get_source(query, sources, 0, from)

    prefix = prefix || ["UPDATE ", name | " SET "]
    table_alias = [" FROM ", from, " AS ", name]
    fields = QueryString.update_fields(query, sources)
    join = QueryString.join(query, sources)
    where = QueryString.where(query, sources)

    IO.iodata_to_binary([prefix, fields, returning(query, sources, "INSERTED"), table_alias, join, where])
  end

  @doc """
  Receives a query and must return a DELETE query.
  """
  @spec delete_all(query :: Ecto.Query.t) :: String.t
  def delete_all(%{from: from} = query) do
    sources = QueryString.create_names(query)
    {from, name} = get_source(query, sources, 0, from)

    join = QueryString.join(query, sources)
    where = QueryString.where(query, sources)

    IO.iodata_to_binary(["DELETE ", name, " FROM ", from, " AS ", name, join, where | returning(query, sources, "DELETED")])
  end

  @doc """
  Returns an INSERT for the given `rows` in `table` returning
  the given `returning`.
  """
  @spec insert(prefix ::String.t, table :: String.t,
                   header :: [atom], rows :: [[atom | nil]],
                   on_conflict :: Ecto.Adapter.on_conflict, returning :: [atom]) :: String.t
  def insert(prefix, table, header, rows, on_conflict, returning) do
    included_fields = header
    |> Enum.filter(fn value -> Enum.any?(rows, fn row -> value in row end) end)
    if included_fields === [] do
      IO.iodata_to_binary(["INSERT INTO ", quote_table(prefix, table),
                           returning(returning, "INSERTED"), " DEFAULT VALUES"])
    else
      included_rows = Enum.map(rows, fn row ->
        row
        |> Enum.zip(header)
        |> Enum.filter_map(
        fn {_row, col} -> col in included_fields end,
        fn {row, _col} -> row end)
      end)
      fields = intersperse_map(included_fields, ?,, &quote_name/1)
      IO.iodata_to_binary(["INSERT INTO ", quote_table(prefix, table),
                           " (", fields, ")",
                           returning(returning, "INSERTED"), " VALUES ",
                           insert_all(included_rows, 1),
                           on_conflict(on_conflict, included_fields)])
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

  # defp insert_all(rows) do
  #   intersperse_map(rows, ?,, fn row ->
  #     [?(, intersperse_map(row, ?,, &insert_all_value/1), ?)]
  #   end)
  # end
  #
  # defp insert_all_value(nil), do: "DEFAULT"
  # defp insert_all_value(_),   do: '?'

  defp returning(%Ecto.Query{select: nil}, _sources, _),
    do: []
  defp returning(%Ecto.Query{select: %{fields: fields}} = query, _sources, operation),
    do: [" OUTPUT " | QueryString.select_fields(fields, {{nil, operation, nil}}, query)]

  defp returning([], _),
    do: []
  defp returning(returning, operation),
    do: [" OUTPUT " | Enum.map_join(returning, ", ", fn column -> [operation, ?. | quote_name(column)] end)]

  @doc """
  Returns an UPDATE for the given `fields` in `table` filtered by
  `filters` returning the given `returning`.
  """
  @spec update(prefix :: String.t, table :: String.t, fields :: [atom],
                   filters :: [atom], returning :: [atom]) :: String.t
  def update(prefix, table, fields, filters, returning) do
    {fields, count} = intersperse_reduce(fields, ", ", 1, fn field, acc ->
      {[quote_name(field), " = ?" | Integer.to_string(acc)], acc + 1}
    end)

    {filters, _count} = intersperse_reduce(filters, " AND ", count, fn field, acc ->
      {[quote_name(field), " = ?" | Integer.to_string(acc)], acc + 1}
    end)

  IO.iodata_to_binary(["UPDATE ", quote_table(prefix, table), " SET ",
                       fields, " WHERE ", filters | returning(returning, "INSERTED")])
  end

  @doc """
  Returns a DELETE for the `filters` returning the given `returning`.
  """
  @spec delete(prefix :: String.t, table :: String.t,
                   filters :: [atom], returning :: [atom]) :: String.t
  def delete(prefix, table, filters, returning) do
    {filters, _} = intersperse_reduce(filters, " AND ", 1, fn field, acc ->
      {[quote_name(field), " = ?" , Integer.to_string(acc)], acc + 1}
    end)

    IO.iodata_to_binary(["DELETE FROM ", quote_table(prefix, table), " WHERE ",
                         filters | returning(returning, "DELETED")])
  end

  ## DDL

  alias Ecto.Migration.{Table, Index, Reference, Constraint}

  @drops [:drop, :drop_if_exists]

  @doc """
  Receives a DDL command and returns a query that executes it.
  """
  @spec execute_ddl(command :: Ecto.Adapter.Migration.command) :: String.t
  def execute_ddl({command, %Table{} = table, columns}) when command in [:create, :create_if_not_exists] do
    query = [if_do(command == :create_if_not_exists,
             "IF NOT EXISTS (SELECT * from SYSOBJECTS WHERE name='#{table.name}' and xtype='U') "),
             "CREATE TABLE ",
             quote_table(table.prefix, table.name), ?\s, ?(,
             column_definitions(table, columns), pk_definition(columns, ", ", table), ?),
             options_expr(table.options)]

    [query]
  end

  def execute_ddl({command, %Table{} = table}) when command in @drops do
    [["DROP TABLE ", if_do(command == :drop_if_exists, "IF EXISTS "),
      quote_table(table.prefix, table.name)]]
  end

  def execute_ddl({:alter, %Table{} = table, changes}) do
    query = [column_changes(table, changes),
             quote_alter(pk_definition(changes, " ADD ", table), table)]

    [query]
  end

  def execute_ddl({:create, %Index{} = index}) do
    fields = intersperse_map(index.columns, ", ", &index_expr/1)

    queries = [["CREATE ",
                if_do(index.unique, "UNIQUE "),
                "INDEX ",
                quote_name(index.name),
                " ON ",
                quote_table(index.prefix, index.table),
                ?\s, ?(, fields, ?),
                if_do(index.where, [" WHERE ", to_string(index.where)])]]

    queries
  end

  def execute_ddl({:create_if_not_exists, %Index{} = index}) do
    raise("create index if not exists: not supported")
  end

  def execute_ddl({command, %Index{} = index}) when command in @drops do
    if_exists = if command == :drop_if_exists, do: "IF EXISTS ", else: []

    [["DROP INDEX ",
      if_exists,
      quote_name(index.name),
      " ON ", quote_table(index.prefix, index.table)]]
  end

  def execute_ddl({:rename, %Table{} = current_table, %Table{} = new_table}) do
    [["EXEC sp_rename ", quote_name([current_table.prefix, current_table.name], ?'),
      ", ", quote_name(new_table.name, ?'), ", 'OBJECT'"]]
  end

  def execute_ddl({:rename, %Table{} = table, current_column, new_column}) do
    [["EXEC sp_rename ", quote_name([table.prefix, table.name, current_column], ?'),
      ", ", quote_name(new_column, ?'), ", 'COLUMN'"]]
  end

  def execute_ddl({:create, %Constraint{} = constraint}) do
    queries = [["ALTER TABLE ", quote_table(constraint.prefix, constraint.table),
                " ADD ", new_constraint_expr(constraint)]]

    queries
  end

  def execute_ddl({:drop, %Constraint{} = constraint}) do
    [["ALTER TABLE ", quote_table(constraint.prefix, constraint.table),
      " DROP CONSTRAINT ", quote_name(constraint.name)]]
  end

  def execute_ddl(string) when is_binary(string), do: [string]

  def execute_ddl(keyword) when is_list(keyword),
    do: error!(nil, "MSSQL adapter does not support keyword lists in execute")

  defp quote_alter([], _table), do: []
  defp quote_alter(statement, table),
    do: ["ALTER TABLE ", quote_table(table.prefix, table.name), statement, "; "]

  defp pk_definition(columns, prefix, table) do
    pks =
      for {_, name, _, opts} <- columns,
          opts[:primary_key],
          do: name

    case pks do
      [] -> []
      _  -> [prefix, "CONSTRAINT ", constraint_name("pk", table),
             " PRIMARY KEY (", intersperse_map(pks, ", ", &quote_name/1), ")"]
    end
  end

  defp column_definitions(table, columns) do
    intersperse_map(columns, ", ", &column_definition(table, &1))
  end

  defp column_definition(table, {:add, name, %Reference{} = ref, opts}) do
    [quote_name(name), ?\s, reference_column_type(ref.type, opts),
     column_options(ref.type, opts, table, name),
     reference_expr(ref, table, name)]
  end

  defp column_definition(table, {:add, name, type, opts}) do
    [quote_name(name), ?\s, column_type(type, opts),
     column_options(type, opts, table, name)]
  end

  defp column_changes(table, columns) do
    {additions, changes} = Enum.split_with(columns,
      fn val -> elem(val, 0) == :add end)
    [if_do(additions !== [], column_additions(additions, table)),
     if_do(changes !== [], Enum.map(changes, &column_change(table, &1)))]
  end

  defp column_additions(additions, table) do
    quote_alter([" ADD ", intersperse_map(additions, ", ", &column_change(table, &1))], table)
  end

  defp column_change(table, {:add, name, %Reference{} = ref, opts}) do
    [quote_name(name), ?\s, reference_column_type(ref.type, opts),
     column_options(ref.type, opts, table, name), reference_expr(ref, table, name)]
  end

  defp column_change(table, {:add, name, type, opts}) do
    [quote_name(name), ?\s, column_type(type, opts),
     column_options(type, opts, table, name)]
  end

  defp column_change(table, {:modify, name, %Reference{} = ref, opts}) do
    [quote_alter(constraint_expr(ref, table, name), table),
     quote_alter([" ALTER COLUMN ", quote_name(name), ?\s, reference_column_type(ref.type, opts), modify_null(name, opts)], table),
     modify_default(name, ref.type, opts, table, name)]
  end

  defp column_change(table, {:modify, name, type, opts}) do
    [quote_alter([" ALTER COLUMN ", quote_name(name), ?\s, column_type(type, opts),
     modify_null(name, opts)], table), modify_default(name, type, opts, table, name)]
  end

  defp column_change(table, {:remove, name}) do
    [if_do(table.primary_key, quote_alter([" DROP CONSTRAINT ", constraint_name("pk", table)], table)),
    quote_alter([" DROP COLUMN ", quote_name(name)], table)]
  end

  defp modify_null(_name, opts) do
    case Keyword.get(opts, :null) do
      nil -> []
      val -> null_expr(val)
    end
  end

  defp modify_default(name, type, opts, table, name) do
    case Keyword.fetch(opts, :default) do
      {:ok, val} ->
        [quote_alter([" DROP CONSTRAINT IF EXISTS ", constraint_name("default", table, name)], table),
         quote_alter([" ADD", default_expr({:ok, val}, type, table, name), " FOR ", quote_name(name)], table)]
      :error -> []
    end
  end

  defp column_options(type, opts, table, name) do
    default = Keyword.fetch(opts, :default)
    null    = Keyword.get(opts, :null)
    [default_expr(default, type, table, name), null_expr(null)]
  end

  defp null_expr(false), do: " NOT NULL"
  defp null_expr(true), do: " NULL"
  defp null_expr(_), do: []

  defp new_constraint_expr(%Constraint{check: check} = constraint) when is_binary(check) do
    ["CONSTRAINT ", quote_name(constraint.name), " CHECK (", check, ")"]
  end

  defp constraint_name(constraint_type, table, name \\ []) do
    sections = [quote_name(table.prefix, nil), quote_name(table.name, nil),
                quote_name(name, nil), constraint_type] |> Enum.reject(&(&1 === []))
    [?", Enum.intersperse(sections, ?_), ?"]
  end

  defp default_expr({:ok, _} = default, type, table, name),
    do: [" CONSTRAINT ", constraint_name("default", table, name),
         default_expr(default, type)]
  defp default_expr(:error, _, _, _),
    do: []
  defp default_expr({:ok, nil}, _type),
    do: " DEFAULT NULL"
  defp default_expr({:ok, []}, _type),
    do: error!(nil, "arrays not supported")
  defp default_expr({:ok, literal}, _type) when is_binary(literal),
    do: [" DEFAULT '", escape_string(literal), ?']
  defp default_expr({:ok, literal}, _type) when is_number(literal),
    do: [" DEFAULT ", to_string(literal)]
  defp default_expr({:ok, literal}, _type) when is_boolean(literal),
    do: [" DEFAULT ", to_string(if literal, do: 1, else: 0)]
  defp default_expr({:ok, {:fragment, expr}}, _type),
    do: [" DEFAULT ", expr]
  defp default_expr({:ok, expr}, type),
    do: raise(ArgumentError, "unknown default `#{inspect expr}` for type `#{inspect type}`. " <>
                             ":default may be a string, number, boolean, empty list or a fragment(...)")

  defp index_expr(literal) when is_binary(literal),
    do: literal
  defp index_expr(literal),
    do: quote_name(literal)

  defp options_expr(nil),
    do: []
  defp options_expr(keyword) when is_list(keyword),
    do: error!(nil, "PostgreSQL adapter does not support keyword lists in :options")
  defp options_expr(options),
    do: [?\s, options]

  defp column_type({:array, type}, opts),
    do: [column_type(type, opts), "[]"]
  defp column_type(type, opts) do
    size      = Keyword.get(opts, :size)
    precision = Keyword.get(opts, :precision)
    scale     = Keyword.get(opts, :scale)
    type_name = ecto_to_db(type)

    cond do
      size            -> [type_name, ?(, to_string(size), ?)]
      precision       -> [type_name, ?(, to_string(precision), ?,, to_string(scale || 0), ?)]
      type == :string -> [type_name, "(255)"]
      true            -> type_name
    end
  end

  defp reference_expr(%Reference{} = ref, table, name),
    do: [" CONSTRAINT ", reference_name(ref, table, name), " REFERENCES ",
         quote_table(table.prefix, ref.table), ?(, quote_name(ref.column), ?),
         reference_on_delete(ref.on_delete), reference_on_update(ref.on_update)]

  defp constraint_expr(%Reference{} = ref, table, name),
    do: [" ADD CONSTRAINT ", reference_name(ref, table, name), ?\s,
         "FOREIGN KEY (", quote_name(name),
         ") REFERENCES ", quote_table(table.prefix, ref.table), ?(, quote_name(ref.column), ?),
         reference_on_delete(ref.on_delete), reference_on_update(ref.on_update)]

  # A reference pointing to a serial column becomes integer in postgres
  defp reference_name(%Reference{name: nil}, table, column),
    do: quote_name("#{table.name}_#{column}_fkey")
  defp reference_name(%Reference{name: name}, _table, _column),
    do: quote_name(name)

  defp reference_column_type(:serial, _opts), do: "int"
  defp reference_column_type(type, opts), do: column_type(type, opts)

  defp reference_on_delete(:nilify_all), do: " ON DELETE SET NULL"
  defp reference_on_delete(:delete_all), do: " ON DELETE CASCADE"
  defp reference_on_delete(_), do: []

  defp reference_on_update(:nilify_all), do: " ON UPDATE SET NULL"
  defp reference_on_update(:update_all), do: " ON UPDATE CASCADE"
  defp reference_on_update(_), do: []
end
