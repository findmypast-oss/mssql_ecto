Logger.configure(level: :info)

# Configure Ecto for support and tests
System.put_env("MSSQL_UID", "sa")
System.put_env("MSSQL_PWD", "ThePa$$word")
Application.put_env(:ecto, :primary_key_type, :id)
Application.put_env(:ecto, :async_integration_tests, false)
Application.put_env(:ecto_sql, :lock_for_update, "FOR UPDATE")

# support paths
ecto = Mix.Project.deps_paths()[:ecto]
ecto_support = ecto <> "/integration_test/support/"
ecto_sql = Mix.Project.deps_paths()[:ecto_sql]
ecto_sql_support = ecto_sql <> "/integration_test/support/"

Code.require_file(ecto_sql_support <> "repo.exs", __DIR__)

# Configure mssql connection
Application.put_env(:ecto_sql, :database, "mssql_ecto_integration_test")

# Basic test repo
alias Ecto.Integration.TestRepo

Application.put_env(
  :ecto_sql,
  TestRepo,
  adapter: MssqlEcto,
  username: System.get_env("MSSQL_UID"),
  password: System.get_env("MSSQL_PWD"),
  database: "mssql_ecto_integration_test",
  pool: Ecto.Adapters.SQL.Sandbox
)

defmodule Ecto.Integration.TestRepo do
  use Ecto.Integration.Repo,
    otp_app: :ecto_sql,
    adapter: MssqlEcto

  def create_prefix(prefix) do
    "create database #{prefix}"
  end

  def drop_prefix(prefix) do
    "drop database #{prefix}"
  end

  def uuid do
    Ecto.UUID
  end
end

# Pool repo for transaction and lock tests
alias Ecto.Integration.PoolRepo

Application.put_env(
  :ecto_sql,
  PoolRepo,
  adapter: MssqlEcto,
  username: System.get_env("MSSQL_UID"),
  password: System.get_env("MSSQL_PWD"),
  database: "mssql_ecto_integration_test",
  pool_size: 10
  #max_restarts: 20,
  #max_seconds: 10
)

defmodule Ecto.Integration.PoolRepo do
  use Ecto.Integration.Repo,
    otp_app: :ecto_sql,
    adapter: MssqlEcto
end

# Load support files
Code.require_file(ecto_support <> "schemas.exs", __DIR__)
Code.require_file(ecto_sql_support <> "migration.exs", __DIR__)

defmodule Ecto.Integration.Case do
  use ExUnit.CaseTemplate

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(TestRepo)
  end
end

{:ok, _} = MssqlEcto.ensure_all_started(TestRepo.config(), :temporary)

# Load up the repository, start it, and run migrations
_ = MssqlEcto.storage_down(TestRepo.config())
:ok = MssqlEcto.storage_up(TestRepo.config())

{:ok, _pid} = TestRepo.start_link()
{:ok, _pid} = PoolRepo.start_link()

# excludes
excludes = [
  :array_type,
  :map_type,
  :uses_usec,
  :uses_msec,
  :modify_foreign_key_on_update,
  :create_index_if_not_exists,
  :not_supported_by_sql_server,
  :upsert,
  :upsert_all,
  :identity_insert
]

ExUnit.configure(exclude: excludes)

:ok = Ecto.Migrator.up(TestRepo, 0, Ecto.Integration.Migration, log: false)
Ecto.Adapters.SQL.Sandbox.mode(TestRepo, :manual)
Process.flag(:trap_exit, true)

ExUnit.start()
