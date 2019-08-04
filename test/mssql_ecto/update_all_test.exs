defmodule MssqlEcto.UpdateAllTest do
  use MssqlEcto.Case, async: true

  import Ecto.Query

  defmodule Schema do
    use Ecto.Schema

    schema "schema" do
      field(:x, :integer)
      field(:y, :integer)
      field(:z, :integer)
      field(:w, {:array, :integer})

      has_many(
        :comments,
        MssqlEctoTest.Schema2,
        references: :x,
        foreign_key: :z
      )

      has_one(
        :permalink,
        MssqlEctoTest.Schema3,
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
        MssqlEctoTest.Schema,
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

  test "update all" do
    query =
      from(m in Schema, update: [set: [x: 0]])
      |> normalize(:update_all)
      |> SQL.update_all()
      |> IO.iodata_to_binary()

    assert query ==
             ~s{UPDATE s0 SET "x" = 0 FROM "schema" AS s0}

    query =
      from(m in Schema, update: [set: [x: 0], inc: [y: 1, z: -3]])
      |> normalize(:update_all)
      |> SQL.update_all()
      |> IO.iodata_to_binary()

    assert query ==
             ~s{UPDATE s0 SET "x" = 0, "y" = s0."y" + 1, "z" = s0."z" + -3 FROM "schema" AS s0}

    query =
      from(e in Schema, where: e.x == 123, update: [set: [x: 0]])
      |> normalize(:update_all)
      |> SQL.update_all()
      |> IO.iodata_to_binary()

    assert query ==
             ~s{UPDATE s0 SET "x" = 0 FROM "schema" AS s0 WHERE (s0."x" = 123)}

    query =
      from(m in Schema, update: [set: [x: ^0]])
      |> normalize(:update_all)
      |> SQL.update_all()
      |> IO.iodata_to_binary()

    assert query ==
             ~s{UPDATE s0 SET "x" = ? FROM "schema" AS s0}

    query =
      Schema
      |> join(:inner, [p], q in Schema2, on: p.x == q.z)
      |> update([_], set: [x: 0])
      |> normalize(:update_all)
      |> SQL.update_all()
      |> IO.iodata_to_binary()

    assert query ==
             ~s{UPDATE s0 SET "x" = 0 FROM "schema" AS s0 INNER JOIN "schema2" AS s1 ON (s0."x" = s1."z")}

    query =
      from(
        e in Schema,
        where: e.x == 123,
        update: [set: [x: 0]],
        join: q in Schema2,
        on: e.x == q.z
      )
      |> normalize(:update_all)
      |> SQL.update_all()
      |> IO.iodata_to_binary()

    assert query ==
             ~s{UPDATE s0 SET "x" = 0 FROM "schema" AS s0 INNER JOIN "schema2" AS s1 } <>
               ~s{ON (s0."x" = s1."z") WHERE (s0."x" = 123)}
  end

  test "update all with returning" do
    query =
      from(m in Schema, update: [set: [x: 0]])
      |> select([m], m)
      |> normalize(:update_all)
      |> SQL.update_all()
      |> IO.iodata_to_binary()

    assert query ==
             ~s{UPDATE s0 SET "x" = 0 OUTPUT INSERTED."id", INSERTED."x", INSERTED."y", INSERTED."z", INSERTED."w" FROM "schema" AS s0}
  end

  # TODO why was this skipped?
  #@tag skip: "Arrays not supported"
  test "update all array ops" do
    query =
      from(m in Schema, update: [push: [w: 0]])
      |> normalize(:update_all)
      |> SQL.update_all()
      |> IO.iodata_to_binary()

    assert query ==
             ~s{UPDATE s0 SET "w" = array_append(s0."w", 0) FROM "schema" AS s0}

    query =
      from(m in Schema, update: [pull: [w: 0]])
      |> normalize(:update_all)
      |> SQL.update_all()
      |> IO.iodata_to_binary()

    assert query ==
             ~s{UPDATE s0 SET "w" = array_remove(s0."w", 0) FROM "schema" AS s0}
  end

  test "update all with prefix" do
    query =
      from(m in Schema, update: [set: [x: 0]])
      |> normalize(:update_all)
      |> Map.put(:prefix, "prefix")
      |> SQL.update_all()
      |> IO.iodata_to_binary()

    assert query ==
             ~s{UPDATE s0 SET "x" = 0 FROM "prefix"."schema" AS s0}
  end
end
