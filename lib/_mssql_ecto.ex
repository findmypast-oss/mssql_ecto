defmodule MssqlEcto do
  # Inherit all behaviour from Ecto.Adapters.SQL
  use Ecto.Adapters.SQL,
    driver: :mssqlex,
    migration_lock: ""

  # And provide a custom storage implementation
  @behaviour Ecto.Adapter.Storage
  @behaviour Ecto.Adapter.Structure

  @doc """
  All Ecto extensions for Mssqlex.
  """
  def extensions do
    []
  end

  # Support arrays in place of IN
  @impl true
  def dumpers({:embed, _} = type, _), do: [&Ecto.Adapters.SQL.dump_embed(type, &1)]
  def dumpers({:map, _} = type, _), do: [&Ecto.Adapters.SQL.dump_embed(type, &1)]
  def dumpers({:in, sub}, {:in, sub}), do: [{:array, sub}]
  def dumpers(:binary_id, type), do: [type, Ecto.UUID]
  def dumpers(_, type), do: [type]

  ## Storage API

  @impl true
  def storage_up(opts) do
    database =
      Keyword.fetch!(opts, :database) || raise ":database is nil in repository configuration"

    opts = Keyword.put(opts, :database, nil)

    command =
      ~s(CREATE DATABASE #{database})
      |> concat_if(opts[:collation], &"COLLATE '#{&1}'")
      |> concat_if(opts[:template], &"TEMPLATE=#{&1}")
      |> concat_if(opts[:lc_ctype], &"LC_CTYPE='#{&1}'")
      |> concat_if(opts[:lc_collate], &"LC_COLLATE='#{&1}'")

    case run_query(command, opts) do
      {:ok, _} ->
        :ok

      {:error, %{odbc_code: :database_already_exists}} ->
        {:error, :already_up}

      {:error, error} ->
        {:error, Exception.message(error)}
    end
  end

  defp concat_if(content, nil, _fun), do: content
  defp concat_if(content, value, fun), do: content <> " " <> fun.(value)

  @impl true
  def storage_down(opts) do
    database =
      Keyword.fetch!(opts, :database) || raise ":database is nil in repository configuration"

    command = "DROP DATABASE #{database}"
    opts = Keyword.put(opts, :database, nil)

    case run_query(command, opts) do
      {:ok, _} ->
        :ok

      {:error, %{odbc_code: :base_table_or_view_not_found}} ->
        {:error, :already_down}

      {:error, error} ->
        {:error, Exception.message(error)}
    end
  end

  @impl true
  def supports_ddl_transaction? do
    true
  end

  @impl true
  def structure_dump(default, config) do
    table = config[:migration_source] || "schema_migrations"

    with {:ok, versions} <- select_versions(table, config),
         {:ok, path} <- pg_dump(default, config),
         do: append_versions(table, versions, path)
  end

  defp select_versions(table, config) do
    case run_query(~s[SELECT version FROM public."#{table}" ORDER BY version], config) do
      {:ok, %{rows: rows}} -> {:ok, Enum.map(rows, &hd/1)}
      {:error, %{mssql: %{code: :undefined_table}}} -> {:ok, []}
      {:error, _} = error -> error
    end
  end

  # TODO this is for postgres, not mssql
  defp pg_dump(default, config) do
    path = config[:dump_path] || Path.join(default, "structure.sql")
    File.mkdir_p!(Path.dirname(path))

    case run_with_cmd("pg_dump", config, [
           "--file",
           path,
           "--schema-only",
           "--no-acl",
           "--no-owner",
           config[:database]
         ]) do
      {_output, 0} ->
        {:ok, path}

      {output, _} ->
        {:error, output}
    end
  end

  defp append_versions(_table, [], path) do
    {:ok, path}
  end

  defp append_versions(table, versions, path) do
    sql =
      ~s[INSERT INTO public."#{table}" (version) VALUES ] <>
        Enum.map_join(versions, ", ", &"(#{&1})") <> ~s[;\n\n]

    File.open!(path, [:append], fn file ->
      IO.write(file, sql)
    end)

    {:ok, path}
  end

  @impl true
  def structure_load(default, config) do
    path = config[:dump_path] || Path.join(default, "structure.sql")

    args = [
      "--quiet",
      "--file",
      path,
      "-vON_ERROR_STOP=1",
      "--single-transaction",
      config[:database]
    ]

    case run_with_cmd("psql", config, args) do
      {_output, 0} -> {:ok, path}
      {output, _} -> {:error, output}
    end
  end

  ## Helpers

  defp run_query(sql, opts) do
    {:ok, _} = Application.ensure_all_started(:mssqlex)

    opts =
      opts
      |> Keyword.drop([:name, :log, :pool, :pool_size])
      |> Keyword.put(:backoff_type, :stop)
      |> Keyword.put(:max_restarts, 0)

    {:ok, pid} = Task.Supervisor.start_link()

    task =
      Task.Supervisor.async_nolink(pid, fn ->
        {:ok, conn} = Mssqlex.start_link(opts)

        value = Mssqlex.query(conn, sql, [], opts)
        GenServer.stop(conn)
        value
      end)

    timeout = Keyword.get(opts, :timeout, 15_000)

    task_return = Task.yield(task, timeout) || Task.shutdown(task)

    case task_return do
      {:ok, {:ok, result}} ->
        {:ok, result}

      {:ok, {:error, error}} ->
        {:error, error}

      {:exit, {%{__struct__: struct} = error, _}}
      when struct in [Mssqlex.Error, DBConnection.Error] ->
        {:error, error}

      {:exit, reason} ->
        {:error, RuntimeError.exception(Exception.format_exit(reason))}

      nil ->
        {:error, RuntimeError.exception("command timed out")}
    end
  end

  defp run_with_cmd(cmd, opts, opt_args) do
    unless System.find_executable(cmd) do
      raise "could not find executable `#{cmd}` in path, " <>
              "please guarantee it is available before running ecto commands"
    end

    env = [{"PGCONNECT_TIMEOUT", "10"}]

    env =
      if password = opts[:password] do
        [{"PGPASSWORD", password} | env]
      else
        env
      end

    args = []
    args = if username = opts[:username], do: ["-U", username | args], else: args
    args = if port = opts[:port], do: ["-p", to_string(port) | args], else: args

    host = opts[:hostname] || System.get_env("PGHOST") || "localhost"
    args = ["--host", host | args]
    args = args ++ opt_args
    System.cmd(cmd, args, env: env, stderr_to_stdout: true)
  end
end
