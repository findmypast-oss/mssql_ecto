# Passing Apparently
Code.require_file "./sql/alter.exs", __DIR__
Code.require_file "./sql/migration.exs", __DIR__
Code.require_file "./sql/sandbox.exs", __DIR__
Code.require_file "./sql/sql.exs", __DIR__
Code.require_file "./sql/subquery.exs", __DIR__
Code.require_file "./cases/joins.exs", __DIR__
Code.require_file "./cases/migrator.exs", __DIR__
Code.require_file "./cases/interval.exs", __DIR__
Code.require_file "./cases/preload.exs", __DIR__
Code.require_file "./cases/assoc.exs", __DIR__
Code.require_file "./cases/type.exs", __DIR__

# Not passing-ish
Code.require_file "./cases/repo.exs", __DIR__       # 3 failures

# NOT SUPPORTED ALLEGEDLY
# Code.require_file "./sql/lock.exs", __DIR__
# Code.require_file "./sql/stream.exs", __DIR__

# PROBABLY WON'T GET FULL SUPPORT AS SQL SERVER IS BAD and you should feel bad
# Code.require_file "./sql/transaction.exs", __DIR__
