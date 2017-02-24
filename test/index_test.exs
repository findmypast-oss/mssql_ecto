defmodule MssqlEcto.IndexTest do
  use ExUnit.Case, async: true
  @moduletag skip: "pending implementation"

  import Ecto.Migration, only: [index: 2, index: 3]

  alias MssqlEcto.Connection, as: SQL

  test "create index" do
    create = {:create, index(:posts, [:category_id, :permalink])}
    assert execute_ddl(create) ==
      [~s|CREATE INDEX "posts_category_id_permalink_index" ON "posts" ("category_id", "permalink")|]

    create = {:create, index(:posts, ["lower(permalink)"], name: "posts$main")}
    assert execute_ddl(create) ==
      [~s|CREATE INDEX "posts$main" ON "posts" (lower(permalink))|]
  end

  test "create index with prefix" do
    create = {:create, index(:posts, [:category_id, :permalink], prefix: :foo)}
    assert execute_ddl(create) ==
      [~s|CREATE INDEX "posts_category_id_permalink_index" ON "foo"."posts" ("category_id", "permalink")|]

    create = {:create, index(:posts, ["lower(permalink)"], name: "posts$main", prefix: :foo)}
    assert execute_ddl(create) ==
      [~s|CREATE INDEX "posts$main" ON "foo"."posts" (lower(permalink))|]
  end

  test "create index with comment" do
    create = {:create, index(:posts, [:category_id, :permalink], prefix: :foo, comment: "comment")}
    assert execute_ddl(create) == [remove_newlines("""
    CREATE INDEX "posts_category_id_permalink_index" ON "foo"."posts" ("category_id", "permalink")
    """)]
  end

  test "create unique index" do
    create = {:create, index(:posts, [:permalink], unique: true)}
    assert execute_ddl(create) ==
      [~s|CREATE UNIQUE INDEX "posts_permalink_index" ON "posts" ("permalink")|]
  end

  test "create unique index with condition" do
    create = {:create, index(:posts, [:permalink], unique: true, where: "public IS TRUE")}
    assert execute_ddl(create) ==
      [~s|CREATE UNIQUE INDEX "posts_permalink_index" ON "posts" ("permalink") WHERE public IS TRUE|]

    create = {:create, index(:posts, [:permalink], unique: true, where: :public)}
    assert execute_ddl(create) ==
      [~s|CREATE UNIQUE INDEX "posts_permalink_index" ON "posts" ("permalink") WHERE public|]
  end

  @tag skip: "not supported"
  test "create index concurrently" do
    create = {:create, index(:posts, [:permalink], concurrently: true)}
    assert execute_ddl(create) ==
      [~s|CREATE INDEX CONCURRENTLY "posts_permalink_index" ON "posts" ("permalink")|]
  end

  @tag skip: "not supported"
  test "create unique index concurrently" do
    create = {:create, index(:posts, [:permalink], concurrently: true, unique: true)}
    assert execute_ddl(create) ==
      [~s|CREATE UNIQUE INDEX CONCURRENTLY "posts_permalink_index" ON "posts" ("permalink")|]
  end

  @tag skip: "not supported"
  test "create an index using a different type" do
    create = {:create, index(:posts, [:permalink], using: :hash)}
    assert execute_ddl(create) ==
      [~s|CREATE INDEX "posts_permalink_index" ON "posts" USING hash ("permalink")|]
  end

  test "drop index" do
    drop = {:drop, index(:posts, [:id], name: "posts$main")}
    assert execute_ddl(drop) == [~s|DROP INDEX "posts$main"|]
  end

  test "drop index with prefix" do
    drop = {:drop, index(:posts, [:id], name: "posts$main", prefix: :foo)}
    assert execute_ddl(drop) == [~s|DROP INDEX "foo"."posts$main"|]
  end

  @tag skip: "not supported"
  test "drop index concurrently" do
    drop = {:drop, index(:posts, [:id], name: "posts$main", concurrently: true)}
    assert execute_ddl(drop) == [~s|DROP INDEX CONCURRENTLY "posts$main"|]
  end

  defp execute_ddl(command) do
    command |> SQL.execute_ddl() |> Enum.map(&IO.iodata_to_binary/1)
  end
  defp remove_newlines(string) do
    string |> String.trim |> String.replace("\n", " ")
  end
end
