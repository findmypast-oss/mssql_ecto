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
    case DBConnection.prepare_execute(conn, %Query{name: name, statement: prepared_query}, params, options) do
      {:ok, query, result} -> {:ok, query, result}
      {:error, %Mssqlex.Error{}} = error -> error
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
  def execute(conn, prepared_query, params, options) do
    IO.inspect prepared_query
    IO.inspect params
    case DBConnection.prepare_execute(conn, %Query{name: "", statement: prepared_query}, params, options) do
      {:ok, _query, result} -> {:ok, result}
      {:error, %Mssqlex.Error{}} = error -> error
      {:error, error} -> raise error
    end
  end

  @doc """
  Returns a stream that prepares and executes the given query with
  `DBConnection`.
  """
  @spec stream(connection :: DBConnection.conn, prepared_query :: prepared, params :: [term], options :: Keyword.t) ::
            Enum.t
  def stream(conn, prepared, params, options) do
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
  def to_constraints(%Mssqlex.Error{}), do: []

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
  def update_all(query) do
    raise("not implemented")
  end

  @doc """
  Receives a query and must return a DELETE query.
  """
  @spec delete_all(query :: Ecto.Query.t) :: String.t
  def delete_all(query) do
    raise("not implemented")
  end

  @doc """
  Returns an INSERT for the given `rows` in `table` returning
  the given `returning`.
  """
  @spec insert(prefix ::String.t, table :: String.t,
                   header :: [atom], rows :: [[atom | nil]],
                   on_conflict :: Ecto.Adapter.on_conflict, returning :: [atom]) :: String.t
  def insert(prefix, table, header, rows, on_conflict, []) do
    fields = intersperse_map(header, ?,, &quote_name/1)
    IO.iodata_to_binary(["INSERT INTO ", quote_table(prefix, table), " (",
                          fields, ") VALUES ", insert_all(rows) |
                          on_conflict(on_conflict, header)])
  end
  def insert(_prefix, _table, _header, _rows, _on_conflict, _returning) do
    error!(nil, "RETURNING is not supported in insert/insert_all by MySQL")
  end

  defp on_conflict({:raise, _, []}, _header) do
    []
  end
  defp on_conflict(_, _header) do
    error!(nil, ":on_conflict options other than :raise are not yet supported")
  end

  defp insert_all(rows) do
    intersperse_map(rows, ?,, fn row ->
      [?(, intersperse_map(row, ?,, &insert_all_value/1), ?)]
    end)
  end

  defp insert_all_value(nil), do: "DEFAULT"
  defp insert_all_value(_),   do: '?'

  @doc """
  Returns an UPDATE for the given `fields` in `table` filtered by
  `filters` returning the given `returning`.
  """
  @spec update(prefix :: String.t, table :: String.t, fields :: [atom],
                   filters :: [atom], returning :: [atom]) :: String.t
  def update(prefix, table, fields, filters, returning) do
    raise("not implemented")
  end

  @doc """
  Returns a DELETE for the `filters` returning the given `returning`.
  """
  @spec delete(prefix :: String.t, table :: String.t,
                   filters :: [atom], returning :: [atom]) :: String.t
  def delete(prefix, table, filters, returning) do
    raise("not implemented")
  end

  ## DDL

  alias Ecto.Migration.{Table, Index, Reference, Constraint}

  @drops [:drop, :drop_if_exists]

  @doc """
  Receives a DDL command and returns a query that executes it.
  """
  @spec execute_ddl(command :: Ecto.Adapter.Migration.command) :: String.t
  def execute_ddl({command, %Table{} = table, columns}) when command in [:create, :create_if_not_exists] do
    query = [if_do(command == :create_if_not_exists, "IF NOT EXISTS (SELECT * from SYSOBJECTS WHERE name='#{table.name}' and xtype='U')"),
             "CREATE TABLE ",
             quote_table(table.prefix, table.name), ?\s, ?(,
             column_definitions(table, columns), pk_definition(columns, ", "), ?),
             options_expr(table.options)]

    [query]
  end

  def execute_ddl({command, %Table{} = table}) when command in @drops do
    [["DROP TABLE ", if_do(command == :drop_if_exists, "IF EXISTS "),
      quote_table(table.prefix, table.name)]]
  end

  def execute_ddl({:alter, %Table{} = table, changes}) do
    query = ["ALTER TABLE ", quote_table(table.prefix, table.name), ?\s,
             column_changes(table, changes), pk_definition(changes, ", ADD ")]

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
    [["DO $$ BEGIN ",
      execute_ddl({:create, index}), ";",
      "EXCEPTION WHEN duplicate_table THEN END; $$;"]]
  end

  def execute_ddl({command, %Index{} = index}) when command in @drops do
    if_exists = if command == :drop_if_exists, do: "IF EXISTS ", else: []

    [["DROP INDEX ",
      if_exists,
      quote_table(index.prefix, index.name)]]
  end

  def execute_ddl({:rename, %Table{} = current_table, %Table{} = new_table}) do
    [["EXEC sp_rename ", quote_name([current_table.prefix, current_table.name], ?'),
      ", ", quote_name(new_table.name, ?'), ", 'TABLE'"]]
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

  defp pk_definition(columns, prefix) do
    pks =
      for {_, name, _, opts} <- columns,
          opts[:primary_key],
          do: name

    case pks do
      [] -> []
      _  -> [prefix, "PRIMARY KEY (", intersperse_map(pks, ", ", &quote_name/1), ")"]
    end
  end

  defp column_definitions(table, columns) do
    intersperse_map(columns, ", ", &column_definition(table, &1))
  end

  defp column_definition(table, {:add, name, %Reference{} = ref, opts}) do
    [quote_name(name), ?\s, reference_column_type(ref.type, opts),
     column_options(ref.type, opts), reference_expr(ref, table, name)]
  end

  defp column_definition(_table, {:add, name, type, opts}) do
    [quote_name(name), ?\s, column_type(type, opts), column_options(type, opts)]
  end

  defp column_changes(table, columns) do
    intersperse_map(columns, ", ", &column_change(table, &1))
  end

  defp column_change(table, {:add, name, %Reference{} = ref, opts}) do
    ["ADD COLUMN ", quote_name(name), ?\s, reference_column_type(ref.type, opts),
     column_options(ref.type, opts), reference_expr(ref, table, name)]
  end

  defp column_change(_table, {:add, name, type, opts}) do
    ["ADD COLUMN ", quote_name(name), ?\s, column_type(type, opts),
     column_options(type, opts)]
  end

  defp column_change(table, {:modify, name, %Reference{} = ref, opts}) do
    ["ALTER COLUMN ", quote_name(name), " TYPE ", reference_column_type(ref.type, opts),
     constraint_expr(ref, table, name), modify_null(name, opts), modify_default(name, ref.type, opts)]
  end

  defp column_change(_table, {:modify, name, type, opts}) do
    ["ALTER COLUMN ", quote_name(name), " TYPE ",
     column_type(type, opts), modify_null(name, opts), modify_default(name, type, opts)]
  end

  defp column_change(_table, {:remove, name}), do: ["DROP COLUMN ", quote_name(name)]

  defp modify_null(name, opts) do
    case Keyword.get(opts, :null) do
      true  -> [", ALTER COLUMN ", quote_name(name), " DROP NOT NULL"]
      false -> [", ALTER COLUMN ", quote_name(name), " SET NOT NULL"]
      nil   -> []
    end
  end

  defp modify_default(name, type, opts) do
    case Keyword.fetch(opts, :default) do
      {:ok, val} -> [", ALTER COLUMN ", quote_name(name), " SET", default_expr({:ok, val}, type)]
      :error -> []
    end
  end

  defp column_options(type, opts) do
    default = Keyword.fetch(opts, :default)
    null    = Keyword.get(opts, :null)
    [default_expr(default, type), null_expr(null)]
  end

  defp null_expr(false), do: " NOT NULL"
  defp null_expr(true), do: " NULL"
  defp null_expr(_), do: []

  defp new_constraint_expr(%Constraint{check: check} = constraint) when is_binary(check) do
    ["CONSTRAINT ", quote_name(constraint.name), " CHECK (", check, ")"]
  end

  defp default_expr({:ok, nil}, _type),
    do: " DEFAULT NULL"
  defp default_expr({:ok, []}, type),
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
  defp default_expr(:error, _),
    do: []

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
    do: [", ADD CONSTRAINT ", reference_name(ref, table, name), ?\s,
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
