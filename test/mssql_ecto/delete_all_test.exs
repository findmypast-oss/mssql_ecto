defmodule MssqlEcto.DeleteAllTest do
  use MssqlEcto.Case, async: true

  import Ecto.Query
  alias Ecto.Queryable

  defmodule Schema do
    use Ecto.Schema

    schema "schema" do
      field(:x, :integer)
      field(:y, :integer)
      field(:z, :integer)
      field(:w, {:array, :integer})

      has_many(
        :comments,
        MssqlEcto.DeleteAllTest.Schema2,
        references: :x,
        foreign_key: :z
      )

      has_one(
        :permalink,
        MssqlEcto.DeleteAllTest.Schema3,
        references: :y,
        foreign_key: :id
      )
    end
  end

  defmodule Schema2 do
    use Ecto.Schema

    schema "schema2" do
      belongs_to(
        :post,
        MssqlEcto.DeleteAllTest.Schema,
        references: :x,
        foreign_key: :z
      )
    end
  end

  defmodule Schema3 do
    use Ecto.Schema

    schema "schema3" do
      field(:list1, {:array, :string})
      field(:list2, {:array, :integer})
      field(:binary, :binary)
    end
  end

  test "delete all" do
    query =
      Schema
      |> Queryable.to_query()
      |> normalize
      |> SQL.delete_all()
      |> IO.iodata_to_binary()

    assert query == ~s{DELETE s0 FROM "schema" AS s0}

    query =
      from(e in Schema, where: e.x == 123)
      |> normalize
      |> SQL.delete_all()
      |> IO.iodata_to_binary()

    assert query ==
             ~s{DELETE s0 FROM "schema" AS s0 WHERE (s0."x" = 123)}

    query =
      Schema
      |> join(:inner, [p], q in Schema2, on: p.x == q.z)
      |> normalize
      |> SQL.delete_all()
      |> IO.iodata_to_binary()

    assert query ==
             ~s{DELETE s0 FROM "schema" AS s0 INNER JOIN "schema2" AS s1 ON (s0."x" = s1."z")}

    query =
      from(e in Schema, where: e.x == 123, join: q in Schema2, on: e.x == q.z)
      |> normalize
      |> SQL.delete_all()
      |> IO.iodata_to_binary()

    assert query ==
             ~s{DELETE s0 FROM "schema" AS s0 INNER JOIN "schema2" AS s1 ON (s0."x" = s1."z") WHERE (s0."x" = 123)}

    query =
      from(
        e in Schema,
        where: e.x == 123,
        join: assoc(e, :comments),
        join: assoc(e, :permalink)
      )
      |> normalize
      |> SQL.delete_all()
      |> IO.iodata_to_binary()

    assert query ==
             ~s{DELETE s0 FROM "schema" AS s0 INNER JOIN "schema2" AS s1 ON (s1."z" = s0."x") INNER JOIN "schema3" AS s2 ON (s2."id" = s0."y") WHERE (s0."x" = 123)}
  end

  test "delete all with returning" do
    query =
      Schema
      |> Queryable.to_query()
      |> select([m], m)
      |> normalize
      |> SQL.delete_all()
      |> IO.iodata_to_binary()

    assert query ==
             ~s{DELETE s0 OUTPUT DELETED."id", DELETED."x", DELETED."y", DELETED."z", DELETED."w" FROM "schema" AS s0}
  end

  test "delete all with prefix" do
    query =
      Schema
      |> Queryable.to_query()

    query =
      %{query | prefix: "prefix"}
      |> normalize
      |> SQL.delete_all()
      |> IO.iodata_to_binary()

    assert query ==
             ~s{DELETE s0 FROM "prefix"."schema" AS s0}
  end
end
