defmodule MssqlEcto.Connection do

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
    raise("not implemented")
  end

  @doc """
  Prepares and executes the given query with `DBConnection`.
  """
  @spec prepare_execute(connection :: DBConnection.t, name :: String.t, prepared, params :: [term], options :: Keyword.t) ::
            {:ok, query :: map, term} | {:error, Exception.t}
  def prepare_execute(conn, name, prepared, params, options) do
    raise("not implemented")
  end

  @doc """
  Executes the given prepared query with `DBConnection`.
  """
  @spec execute(connection :: DBConnection.t, prepared_query :: prepared, params :: [term], options :: Keyword.t) ::
            {:ok, term} | {:error, Exception.t}
  @spec execute(connection :: DBConnection.t, prepared_query :: cached, params :: [term], options :: Keyword.t) ::
            {:ok, term} | {:error | :reset, Exception.t}
  def execute(conn, prepared, params, options) do
    raise("not implemented")
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
  def to_constraints(exception) do
    raise("not implemented")
  end

  ## Queries

  @doc """
  Receives a query and must return a SELECT query.
  """
  @spec all(query :: Ecto.Query.t) :: String.t
  def all(query) do
    raise("not implemented")
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
  def insert(prefix, table, header, rows, on_conflict, returning) do
    raise("not implemented")
  end

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

  @doc """
  Receives a DDL command and returns a query that executes it.
  """
  @spec execute_ddl(command :: Ecto.Adapter.Migration.command) :: String.t
  def execute_ddl(command) do
    raise("not implemented")
  end
end
