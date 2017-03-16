Logger.configure(level: :info)
ExUnit.start exclude: [:array_type,
                       :map_type,
                       :uses_usec,
                       :uses_msec,
                       :parallel_preloader,
                       :modify_foreign_key_on_update,
                       :create_index_if_not_exists,
                       :not_supported_by_sql_server,
                       :upsert,
                       :upsert_all]

# Configure Ecto for support and tests
Application.put_env(:ecto, :primary_key_type, :id)
Application.put_env(:ecto, :lock_for_update, "FOR UPDATE")
# Load support files
Code.require_file "./support/repo.exs", __DIR__
Code.require_file "./support/schemas.exs", __DIR__
Code.require_file "./support/migration.exs", __DIR__

pool =
  case System.get_env("ECTO_POOL") || "poolboy" do
    "poolboy" -> DBConnection.Poolboy
    "sbroker" -> DBConnection.Sojourn
  end

# Basic test repo
alias Ecto.Integration.TestRepo

Application.put_env(:ecto, TestRepo,
  adapter: MssqlEcto,
  username: System.get_env("MSSQL_UID"),
  password: System.get_env("MSSQL_PWD"),
  database: "mssql_ecto_integration_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  ownership_pool: pool)

defmodule Ecto.Integration.TestRepo do
  use Ecto.Integration.Repo, otp_app: :ecto
end

# Pool repo for transaction and lock tests
alias Ecto.Integration.PoolRepo

Application.put_env(:ecto, PoolRepo,
  adapter: MssqlEcto,
  pool: pool,
  username: System.get_env("MSSQL_UID"),
  password: System.get_env("MSSQL_PWD"),
  database: "mssql_ecto_integration_test",
  pool_size: 10,
  max_restarts: 20,
  max_seconds: 10)

defmodule Ecto.Integration.PoolRepo do
  use Ecto.Integration.Repo, otp_app: :ecto

  def create_prefix(prefix) do
   "create schema #{prefix}"
  end

  def drop_prefix(prefix) do
   "drop schema #{prefix}"
  end
end

defmodule Ecto.Integration.Case do
  use ExUnit.CaseTemplate

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(TestRepo)
  end
end

{:ok, _} = MssqlEcto.ensure_all_started(TestRepo, :temporary)

# Load up the repository, start it, and run migrations
_   = MssqlEcto.storage_down(TestRepo.config())
:ok = MssqlEcto.storage_up(TestRepo.config())

{:ok, _pid} = TestRepo.start_link
{:ok, _pid} = PoolRepo.start_link

:ok = Ecto.Migrator.up(TestRepo, 0, Ecto.Integration.Migration, log: false)
Ecto.Adapters.SQL.Sandbox.mode(TestRepo, :manual)
Process.flag(:trap_exit, true)
