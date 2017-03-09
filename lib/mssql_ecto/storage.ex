defmodule MssqlEcto.Storage do

  defmacro __using__(_) do
    quote do
      @behaviour Ecto.Adapter.Storage

      def storage_up(opts) do
        database = Keyword.fetch!(opts, :database) || raise ":database is nil in repository configuration"
        opts     = Keyword.put(opts, :database, nil)

        command =
          ~s(CREATE DATABASE "#{database}")
          |> concat_if(opts[:collation], &"COLLATE '#{&1}'")
          |> concat_if(opts[:template], &"TEMPLATE=#{&1}")
          |> concat_if(opts[:lc_ctype], &"LC_CTYPE='#{&1}'")
          |> concat_if(opts[:lc_collate], &"LC_COLLATE='#{&1}'")

        case run_query(command, opts) do
          {:ok, _} ->
            :ok
          {:error, %{odbc_code: :base_table_or_view_already_exists}} ->
            {:error, :already_up}
          {:error, error} ->
            {:error, Exception.message(error)}
        end
      end

      defp concat_if(content, nil, _fun),  do: content
      defp concat_if(content, value, fun), do: content <> " " <> fun.(value)

      @doc false
      def storage_down(opts) do
        database = Keyword.fetch!(opts, :database) || raise ":database is nil in repository configuration"
        command  = "DROP DATABASE \"#{database}\""
        opts     = Keyword.put(opts, :database, nil)

        case run_query(command, opts) do
          {:ok, _} ->
            :ok
          {:error, %{postgres: %{code: :invalid_catalog_name}}} ->
            {:error, :already_down}
          {:error, error} ->
            {:error, Exception.message(error)}
        end
      end

      @doc false
      def supports_ddl_transaction? do
        false
      end

      @doc false
      def structure_dump(default, config) do
        table = config[:migration_source] || "schema_migrations"

        raise "not implemented"
        # with {:ok, versions} <- select_versions(table, config),
        #      {:ok, path} <- pg_dump(default, config),
             # do: append_versions(table, versions, path)
      end

      ## Helpers

      defp select_versions(table, config) do
        case run_query(~s[SELECT version FROM "#{table}" ORDER BY version], config) do
          {:ok, %{rows: rows}} -> {:ok, Enum.map(rows, &hd/1)}
          {:error, %{postgres: %{code: :undefined_table}}} -> {:ok, []}
          {:error, _} = error -> error
        end
      end

      defp append_versions(_table, [], path) do
        {:ok, path}
      end
      defp append_versions(table, versions, path) do
        sql =
          ~s[INSERT INTO "#{table}" (version) VALUES ] <>
          Enum.map_join(versions, ", ", &"(#{&1})") <>
          ~s[;\n\n]

        File.open!(path, [:append], fn file ->
          IO.write(file, sql)
        end)

        {:ok, path}
      end

      @doc false
      def structure_load(default, config) do
        path = config[:dump_path] || Path.join(default, "structure.sql")

        raise "not implemented"
        # case run_with_cmd("psql", config, ["--quiet", "--file", path, config[:database]]) do
        #   {_output, 0} -> {:ok, path}
        #   {output, _}  -> {:error, output}
        # end
      end

      defp run_query(sql, opts) do
        {:ok, _} = Application.ensure_all_started(:mssqlex)

        opts =
          opts
          |> Keyword.drop([:name, :log])
          |> Keyword.put(:pool, DBConnection.Connection)
          |> Keyword.put(:backoff_type, :stop)

        {:ok, pid} = Task.Supervisor.start_link

        task = Task.Supervisor.async_nolink(pid, fn ->
          {:ok, conn} = DBConnection.start_link(Mssqlex.Protocol, opts)
          value = MssqlEcto.Connection.execute(conn, sql, [], opts)
          GenServer.stop(conn)
          value
        end)

        timeout = Keyword.get(opts, :timeout, 15_000)

        case Task.yield(task, timeout) || Task.shutdown(task) do
          {:ok, {:ok, result}} ->
            {:ok, result}
          {:ok, {:error, error}} ->
            {:error, error}
          {:exit, {%{__struct__: struct} = error, _}}
              when struct in [DBConnection.Error] ->
            {:error, error}
          {:exit, reason}  ->
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

        env =
          [{"PGCONNECT_TIMEOUT", "10"}]
        env =
          if password = opts[:password] do
            [{"PGPASSWORD", password}|env]
          else
            env
          end

        args =
          []
        args =
          if username = opts[:username], do: ["-U", username|args], else: args
        args =
          if port = opts[:port], do: ["-p", to_string(port)|args], else: args

        host = opts[:hostname] || System.get_env("PGHOST") || "localhost"
        args = ["--host", host|args]
        args = args ++ opt_args
        System.cmd(cmd, args, env: env, stderr_to_stdout: true)
      end
    end
  end
end
