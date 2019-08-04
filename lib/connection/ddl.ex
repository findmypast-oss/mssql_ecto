defmodule MssqlEcto.Connection.DDL do
  alias Ecto.Migration.{Table, Index, Reference, Constraint}
  import MssqlEcto.Connection.Helper

  @creates [:create, :create_if_not_exists]
  @drops [:drop, :drop_if_exists]

  def logs(%Mssqlex.Result{} = result) do
    messages =
      case result do
        %{messages: messages} ->
          messages

        _ ->
          []
      end

    for message <- messages do
      %{message: message, severity: severity} = message

      {ddl_log_level(severity), message, []}
    end
  end

  # TODO these are for Postgres, maybe irrelevant for MSSQL
  defp ddl_log_level("DEBUG"), do: :debug
  defp ddl_log_level("LOG"), do: :info
  defp ddl_log_level("INFO"), do: :info
  defp ddl_log_level("NOTICE"), do: :info
  defp ddl_log_level("WARNING"), do: :warn
  defp ddl_log_level("ERROR"), do: :error
  defp ddl_log_level("FATAL"), do: :error
  defp ddl_log_level("PANIC"), do: :error
  defp ddl_log_level(_severity), do: :info

  def table_exists_query(table) do
    {"SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ?",
     [table]}
  end

  # execute dll (all MSSQL from here on)
  def execute({command, %Table{} = table, columns})
      when command in @creates do
    query = [
      if_do(
        command == :create_if_not_exists,
        "IF NOT EXISTS (SELECT * from SYSOBJECTS WHERE name='#{table.name}' and xtype='U') "
      ),
      "CREATE TABLE ",
      quote_table(table.prefix, table.name),
      ?\s,
      ?(,
      column_definitions(table, columns),
      pk_definition(columns, ", ", table),
      ?),
      options_expr(table.options)
    ]

    [query]
  end

  def execute({command, %Table{} = table}) when command in @drops do
    [
      [
        if_do(
          command == :drop_if_exists,
          "IF OBJECT_ID('#{table.prefix}#{table.name}', 'U') IS NOT NULL "
        ),
        "DROP TABLE ",
        quote_table(table.prefix, table.name)
      ]
    ]
  end

  def execute({:alter, %Table{} = table, changes}) do
    query = [
      column_changes(table, changes),
      quote_alter(pk_definition(changes, " ADD ", table), table)
    ]

    [query]
  end

  def execute({:create, %Index{} = index}) do
    fields = intersperse_map(index.columns, ", ", &index_expr/1)

    queries = [
      [
        "CREATE ",
        if_do(index.unique, "UNIQUE "),
        "INDEX ",
        quote_name(index.name),
        " ON ",
        quote_table(index.prefix, index.table),
        ?\s,
        ?(,
        fields,
        ?),
        if_do(index.where, [" WHERE ", to_string(index.where)])
      ]
    ]

    queries
  end

  def execute({:create_if_not_exists, %Index{} = _index}) do
    raise("create index if not exists: not supported")
  end

  def execute({command, %Index{} = index}) when command in @drops do
    if_exists = if command == :drop_if_exists, do: "IF EXISTS ", else: []

    [
      [
        "DROP INDEX ",
        if_exists,
        quote_name(index.name),
        " ON ",
        quote_table(index.prefix, index.table)
      ]
    ]
  end

  def execute({:rename, %Table{} = current_table, %Table{} = new_table}) do
    [
      [
        "EXEC sp_rename ",
        quote_name([current_table.prefix, current_table.name], ?'),
        ", ",
        quote_name(new_table.name, ?'),
        ", 'OBJECT'"
      ]
    ]
  end

  def execute({:rename, %Table{} = table, current_column, new_column}) do
    [
      [
        "EXEC sp_rename ",
        quote_name([table.prefix, table.name, current_column], ?'),
        ", ",
        quote_name(new_column, ?'),
        ", 'COLUMN'"
      ]
    ]
  end

  def execute({:create, %Constraint{} = constraint}) do
    queries = [
      [
        "ALTER TABLE ",
        quote_table(constraint.prefix, constraint.table),
        " ADD ",
        new_constraint_expr(constraint)
      ]
    ]

    queries
  end

  def execute({:drop, %Constraint{} = constraint}) do
    [
      [
        "ALTER TABLE ",
        quote_table(constraint.prefix, constraint.table),
        " DROP CONSTRAINT ",
        quote_name(constraint.name)
      ]
    ]
  end

  def execute(string) when is_binary(string), do: [string]

  def execute(keyword) when is_list(keyword),
    do: error!(nil, "MSSQL adapter does not support keyword lists in execute")

  @doc false
  def supports_ddl_transaction? do
    false
  end

  ## Helpers

  defp quote_alter([], _table), do: []

  defp quote_alter(statement, table),
    do: ["ALTER TABLE ", quote_table(table.prefix, table.name), statement, "; "]

  defp pk_definition(columns, prefix, table) do
    pks = for {_, name, _, opts} <- columns, opts[:primary_key], do: name

    case pks do
      [] ->
        []

      _ ->
        [
          prefix,
          "CONSTRAINT ",
          constraint_name("pk", table),
          " PRIMARY KEY (",
          intersperse_map(pks, ", ", &quote_name/1),
          ")"
        ]
    end
  end

  defp column_definitions(table, columns) do
    intersperse_map(columns, ", ", &column_definition(table, &1))
  end

  defp column_definition(table, {:add, name, %Reference{} = ref, opts}) do
    [
      quote_name(name),
      ?\s,
      reference_column_type(ref.type, opts),
      column_options(ref.type, opts, table, name),
      reference_expr(ref, table, name)
    ]
  end

  defp column_definition(table, {:add, name, type, opts}) do
    [
      quote_name(name),
      ?\s,
      column_type(type, opts),
      column_options(type, opts, table, name)
    ]
  end

  defp column_changes(table, columns) do
    {additions, changes} = Enum.split_with(columns, fn val -> elem(val, 0) == :add end)

    [
      if_do(additions !== [], column_additions(additions, table)),
      if_do(changes !== [], Enum.map(changes, &column_change(table, &1)))
    ]
  end

  defp column_additions(additions, table) do
    quote_alter(
      [" ADD ", intersperse_map(additions, ", ", &column_change(table, &1))],
      table
    )
  end

  defp column_change(table, {:add, name, %Reference{} = ref, opts}) do
    [
      quote_name(name),
      ?\s,
      reference_column_type(ref.type, opts),
      column_options(ref.type, opts, table, name),
      reference_expr(ref, table, name)
    ]
  end

  defp column_change(table, {:add, name, type, opts}) do
    [
      quote_name(name),
      ?\s,
      column_type(type, opts),
      column_options(type, opts, table, name)
    ]
  end

  defp column_change(table, {:modify, name, %Reference{} = ref, opts}) do
    [
      quote_alter(constraint_expr(ref, table, name), table),
      quote_alter(
        [
          " ALTER COLUMN ",
          quote_name(name),
          ?\s,
          reference_column_type(ref.type, opts),
          modify_null(name, opts)
        ],
        table
      ),
      modify_default(name, ref.type, opts, table, name)
    ]
  end

  defp column_change(table, {:modify, name, type, opts}) do
    [
      quote_alter(
        [
          " ALTER COLUMN ",
          quote_name(name),
          ?\s,
          column_type(type, opts),
          modify_null(name, opts)
        ],
        table
      ),
      modify_default(name, type, opts, table, name)
    ]
  end

  defp column_change(table, {:remove, name}) do
    [
      if_do(
        table.primary_key,
        quote_alter([" DROP CONSTRAINT ", constraint_name("pk", table)], table)
      ),
      quote_alter([" DROP COLUMN ", quote_name(name)], table)
    ]
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
        constraint_tag = constraint_name("default", table, name)

        [
          "IF OBJECT_ID('",
          constraint_tag,
          "', 'D') IS NOT NULL ",
          quote_alter(
            [" DROP CONSTRAINT ", constraint_name("default", table, name)],
            table
          ),
          quote_alter(
            [
              " ADD",
              default_expr({:ok, val}, type, table, name),
              " FOR ",
              quote_name(name)
            ],
            table
          )
        ]

      :error ->
        []
    end
  end

  defp column_options(type, opts, table, name) do
    default = Keyword.fetch(opts, :default)
    null = Keyword.get(opts, :null)
    [default_expr(default, type, table, name), null_expr(null)]
  end

  defp null_expr(false), do: " NOT NULL"
  defp null_expr(true), do: " NULL"
  defp null_expr(_), do: []

  defp new_constraint_expr(%Constraint{check: check} = constraint)
       when is_binary(check) do
    ["CONSTRAINT ", quote_name(constraint.name), " CHECK (", check, ")"]
  end

  defp constraint_name(constraint_type, table, name \\ []) do
    sections =
      [
        quote_name(table.prefix, nil),
        quote_name(table.name, nil),
        quote_name(name, nil),
        constraint_type
      ]
      |> Enum.reject(&(&1 === []))

    [?", Enum.intersperse(sections, ?_), ?"]
  end

  defp default_expr({:ok, _} = default, type, table, name),
    do: [
      " CONSTRAINT ",
      constraint_name("default", table, name),
      default_expr(default, type)
    ]

  defp default_expr(:error, _, _, _), do: []
  defp default_expr({:ok, nil}, _type), do: " DEFAULT NULL"
  defp default_expr({:ok, []}, _type), do: error!(nil, "arrays not supported")

  defp default_expr({:ok, literal}, _type) when is_binary(literal),
    do: [" DEFAULT '", escape_string(literal), ?']

  defp default_expr({:ok, literal}, _type) when is_number(literal),
    do: [" DEFAULT ", to_string(literal)]

  defp default_expr({:ok, literal}, _type) when is_boolean(literal),
    do: [" DEFAULT ", to_string(if literal, do: 1, else: 0)]

  defp default_expr({:ok, {:fragment, expr}}, _type), do: [" DEFAULT ", expr]

  defp default_expr({:ok, expr}, type),
    do:
      raise(
        ArgumentError,
        "unknown default `#{inspect(expr)}` for type `#{inspect(type)}`. " <>
          ":default may be a string, number, boolean, empty list or a fragment(...)"
      )

  defp index_expr(literal) when is_binary(literal), do: literal
  defp index_expr(literal), do: quote_name(literal)

  defp options_expr(nil), do: []

  defp options_expr(keyword) when is_list(keyword),
    do:
      error!(
        nil,
        "Microsoft SQL Server adapter does not support keyword lists in :options"
      )

  defp options_expr(options), do: [?\s, options]

  defp column_type({:array, type}, opts), do: [column_type(type, opts), "[]"]

  defp column_type(type, opts) do
    size = Keyword.get(opts, :size)
    precision = Keyword.get(opts, :precision)
    scale = Keyword.get(opts, :scale)
    type_name = ecto_to_db(type)

    cond do
      size ->
        [type_name, ?(, to_string(size), ?)]

      precision ->
        [type_name, ?(, to_string(precision), ?,, to_string(scale || 0), ?)]

      type == :string ->
        [type_name, "(255)"]

      true ->
        type_name
    end
  end

  defp reference_expr(%Reference{} = ref, table, name),
    do: [
      " CONSTRAINT ",
      reference_name(ref, table, name),
      " REFERENCES ",
      quote_table(table.prefix, ref.table),
      ?(,
      quote_name(ref.column),
      ?),
      reference_on_delete(ref.on_delete),
      reference_on_update(ref.on_update)
    ]

  defp constraint_expr(%Reference{} = ref, table, name),
    do: [
      " ADD CONSTRAINT ",
      reference_name(ref, table, name),
      ?\s,
      "FOREIGN KEY (",
      quote_name(name),
      ") REFERENCES ",
      quote_table(table.prefix, ref.table),
      ?(,
      quote_name(ref.column),
      ?),
      reference_on_delete(ref.on_delete),
      reference_on_update(ref.on_update)
    ]

  defp reference_name(%Reference{name: nil}, table, column),
    do: quote_name("#{table.name}_#{column}_fkey")

  defp reference_name(%Reference{name: name}, _table, _column),
    do: quote_name(name)

  defp reference_column_type(:serial, _opts), do: "int"
  defp reference_column_type(:bigserial, _opts), do: "bigint"
  defp reference_column_type(type, opts), do: column_type(type, opts)

  defp reference_on_delete(:nilify_all), do: " ON DELETE SET NULL"
  defp reference_on_delete(:delete_all), do: " ON DELETE CASCADE"
  defp reference_on_delete(_), do: []

  defp reference_on_update(:nilify_all), do: " ON UPDATE SET NULL"
  defp reference_on_update(:update_all), do: " ON UPDATE CASCADE"
  defp reference_on_update(_), do: []
end
