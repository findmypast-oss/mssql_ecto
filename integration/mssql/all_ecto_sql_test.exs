ecto_sql = Mix.Project.deps_paths()[:ecto_sql]
ecto_sql = "#{ecto_sql}/integration_test/sql"

Code.require_file("alter.exs", ecto_sql)
Code.require_file("logging.exs", ecto_sql)
Code.require_file("migration.exs", ecto_sql)
Code.require_file("migrator.exs", ecto_sql)
Code.require_file("sql.exs", ecto_sql)
Code.require_file("subquery.exs", ecto_sql)

# should support
#Code.require_file("sandbox.exs", ecto_sql)

# Partial / No Support
#Code.require_file("stream.exs", ecto_sql)
#Code.require_file("transaction.exs", ecto_sql)
#Code.require_file("lock.exs", ecto_sql)
