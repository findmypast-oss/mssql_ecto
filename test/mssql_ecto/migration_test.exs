defmodule MssqlEcto.MigrationTest do
  use MssqlEcto.Case, async: true

  import Ecto.Migration, only: [table: 1, table: 2]

  test "executing a string during migration" do
    assert execute_ddl("example") == ["example"]
  end

  test "rename table" do
    rename = {:rename, table(:posts), table(:new_posts)}

    assert execute_ddl(rename) == [
             ~s|EXEC sp_rename 'posts', 'new_posts', 'OBJECT'|
           ]
  end

  test "rename table with prefix" do
    rename =
      {:rename, table(:posts, prefix: :foo), table(:new_posts, prefix: :foo)}

    assert execute_ddl(rename) == [
             ~s|EXEC sp_rename 'foo.posts', 'new_posts', 'OBJECT'|
           ]
  end

  test "rename column" do
    rename = {:rename, table(:posts), :given_name, :first_name}

    assert execute_ddl(rename) == [
             ~s|EXEC sp_rename 'posts.given_name', 'first_name', 'COLUMN'|
           ]
  end

  test "rename column in prefixed table" do
    rename = {:rename, table(:posts, prefix: :foo), :given_name, :first_name}

    assert execute_ddl(rename) == [
             ~s|EXEC sp_rename 'foo.posts.given_name', 'first_name', 'COLUMN'|
           ]
  end

  defp execute_ddl(command) do
    command |> SQL.execute_ddl() |> Enum.map(&IO.iodata_to_binary/1)
  end
end
