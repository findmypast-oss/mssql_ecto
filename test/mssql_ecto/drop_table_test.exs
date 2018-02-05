defmodule MssqlEcto.DropTableTest do
  use MssqlEcto.Case, async: true

  import Ecto.Migration, only: [table: 1, table: 2]

  test "drop table" do
    drop = {:drop, table(:posts)}
    assert execute_ddl(drop) == [~s|DROP TABLE "posts"|]
  end

  test "drop table with prefix" do
    drop = {:drop, table(:posts, prefix: :foo)}
    assert execute_ddl(drop) == [~s|DROP TABLE "foo"."posts"|]
  end

  defp execute_ddl(command) do
    command |> SQL.execute_ddl() |> Enum.map(&IO.iodata_to_binary/1)
  end
end
