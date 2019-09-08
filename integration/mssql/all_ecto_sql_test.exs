ecto_sql = Mix.Project.deps_paths()[:ecto_sql]
ecto_sql = "#{ecto_sql}/integration_test/sql"

Code.require_file("logging.exs", ecto_sql)
Code.require_file("sandbox.exs", ecto_sql)
Code.require_file("sql.exs", ecto_sql)

"""

# Partial Support

> Code.require_file("subquery.exs", ecto_sql)
1 test fails due to the mssql order by clause.

> Code.require_file("alter.exs", ecto_sql)
ODBC handles Decimal's in a different way to what ecto expects.

> Code.require_file("migration.exs", ecto_sql)
Most tests pass. Of the three failing tests two seem to be because of MSSQL specific behaviour.


# No Support
These tests fail because of the "No SQL-driver information available." error.
I think it is because the lock isn't implemented properly.

> Code.require_file("transaction.exs", ecto_sql)
> Code.require_file("lock.exs", ecto_sql)
> Code.require_file("migrator.exs", ecto_sql)


# Not Implemented
> Code.require_file("stream.exs", ecto_sql)
"""
