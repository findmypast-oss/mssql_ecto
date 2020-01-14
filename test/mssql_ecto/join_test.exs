defmodule MssqlEcto.JoinTest do
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
        MssqlEcto.JoinTest.Schema2,
        references: :x,
        foreign_key: :z
      )

      has_one(
        :permalink,
        MssqlEcto.JoinTest.Schema3,
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
        MssqlEcto.JoinTest.Schema,
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

  defp parse(query, prefix) do
    query =
      query
      |> normalize

    SQL.all(%{query | prefix: prefix})
    |> IO.iodata_to_binary()
  end

  defp parse(query) do
    query
    |> normalize
    |> SQL.all()
    |> IO.iodata_to_binary()
  end

  test "join" do
    query =
      Schema
      |> join(:inner, [p], q in Schema2, on: p.x == q.z)
      |> select([], true)
      |> parse()

    assert query ==
             ~s{SELECT 'TRUE' FROM "schema" AS s0 INNER JOIN "schema2" AS s1 ON (s0."x" = s1."z")}

    query =
      Schema
      |> join(:inner, [p], q in Schema2, on: p.x == q.z)
      |> join(:inner, [], Schema)
      |> select([], true)
      |> parse()

    assert query ==
             ~s{SELECT 'TRUE' FROM "schema" AS s0 INNER JOIN "schema2" AS s1 ON (s0."x" = s1."z") } <>
               ~s{INNER JOIN "schema" AS s2 ON (1=1)}
  end

  test "join with nothing bound" do
    query =
      Schema
      |> join(:inner, [], q in Schema2, on: q.z == q.z)
      |> select([], true)
      |> parse()

    assert query ==
             ~s{SELECT 'TRUE' FROM "schema" AS s0 INNER JOIN "schema2" AS s1 ON (s1."z" = s1."z")}
  end

  test "join without schema" do
    query =
      "posts"
      |> join(:inner, [p], q in "comments", on: p.x == q.z)
      |> select([], true)
      |> parse()

    assert query ==
             ~s{SELECT 'TRUE' FROM "posts" AS p0 INNER JOIN "comments" AS c1 ON (p0."x" = c1."z")}
  end

  test "join with subquery" do
    posts =
      subquery(
        "posts"
        |> where(title: ^"hello")
        |> select([r], %{x: r.x, y: r.y})
      )

    query =
      "comments"
      |> join(:inner, [c], p in subquery(posts))
      |> select([_, p], p.x)
      |> parse()

    assert query ==
             ~s{SELECT s1."x" FROM "comments" AS c0 } <>
               ~s{INNER JOIN (SELECT p0."x" AS "x", p0."y" AS "y" FROM "posts" AS p0 WHERE (p0."title" = ?)) AS s1 ON (1=1)}

    posts =
      subquery(
        "posts"
        |> where(title: ^"hello")
        |> select([r], %{x: r.x, z: r.y})
      )

    query =
      "comments"
      |> join(:inner, [c], p in subquery(posts))
      |> select([_, p], p)
      |> parse()

    assert query ==
             ~s{SELECT s1."x", s1."z" FROM "comments" AS c0 } <>
               ~s{INNER JOIN (SELECT p0."x" AS "x", p0."y" AS "z" FROM "posts" AS p0 WHERE (p0."title" = ?)) AS s1 ON (1=1)}
  end

  test "join with prefix" do
    query =
      Schema
      |> join(:inner, [p], q in Schema2, on: p.x == q.z)
      |> select([], true)
      |> parse("prefix")

    assert query ==
             ~s{SELECT 'TRUE' FROM "prefix"."schema" AS s0 INNER JOIN "prefix"."schema2" AS s1 ON (s0."x" = s1."z")}
  end

  test "join with fragment" do
    query =
      Schema
      |> join(
        :inner,
        [p],
        q in fragment(
          "SELECT * FROM schema2 AS s2 WHERE s2.id = ? AND s2.field = ?",
          p.x,
          ^10
        )
      )
      |> select([p], {p.id, ^0})
      |> where([p], p.id > 0 and p.id < ^100)
      |> parse()

    assert query ==
             ~s{SELECT s0."id", ? FROM "schema" AS s0 INNER JOIN } <>
               ~s{(SELECT * FROM schema2 AS s2 WHERE s2.id = s0."x" AND s2.field = ?) AS f1 ON (1=1) } <>
               ~s{WHERE ((s0."id" > 0) AND (s0."id" < ?))}
  end

  test "join with fragment and on defined" do
    query =
      Schema
      |> join(:inner, [p], q in fragment("SELECT * FROM schema2"), on: q.id == p.id)
      |> select([p], {p.id, ^0})
      |> parse()

    assert query ==
             ~s{SELECT s0."id", ? FROM "schema" AS s0 INNER JOIN } <>
               ~s{(SELECT * FROM schema2) AS f1 ON (f1."id" = s0."id")}
  end

  test "lateral join with fragment" do
    query =
      Schema
      |> join(
        :inner_lateral,
        [p],
        q in fragment(
          "SELECT * FROM schema2 AS s2 WHERE s2.id = ? AND s2.field = ?",
          p.x,
          ^10
        )
      )
      |> select([p, q], {p.id, q.z})
      |> where([p], p.id > 0 and p.id < ^100)
      |> parse()

    assert query ==
             ~s{SELECT s0."id", f1."z" FROM "schema" AS s0 INNER JOIN LATERAL } <>
               ~s{(SELECT * FROM schema2 AS s2 WHERE s2.id = s0."x" AND s2.field = ?) AS f1 ON (1=1) } <>
               ~s{WHERE ((s0."id" > 0) AND (s0."id" < ?))}
  end

  test "association join belongs_to" do
    query =
      Schema2
      |> join(:inner, [c], p in assoc(c, :post))
      |> select([], true)
      |> parse()

    assert query ==
             "SELECT 'TRUE' FROM \"schema2\" AS s0 INNER JOIN \"schema\" AS s1 ON (s1.\"x\" = s0.\"z\")"
  end

  test "association join has_many" do
    query =
      Schema
      |> join(:inner, [p], c in assoc(p, :comments))
      |> select([], true)
      |> parse()

    assert query ==
             "SELECT 'TRUE' FROM \"schema\" AS s0 INNER JOIN \"schema2\" AS s1 ON (s1.\"z\" = s0.\"x\")"
  end

  test "association join has_one" do
    query =
      Schema
      |> join(:inner, [p], pp in assoc(p, :permalink))
      |> select([], true)
      |> parse()

    assert query ==
             "SELECT 'TRUE' FROM \"schema\" AS s0 INNER JOIN \"schema3\" AS s1 ON (s1.\"id\" = s0.\"y\")"
  end

  test "join produces correct bindings" do
    query = from(p in Schema, join: c in Schema2, on: true)

    query =
      from(p in query, join: c in Schema2, on: true, select: {p.id, c.id})
      |> parse()

    assert query ==
             "SELECT s0.\"id\", s2.\"id\" FROM \"schema\" AS s0 INNER JOIN \"schema2\" AS s1 ON (1=1) INNER JOIN \"schema2\" AS s2 ON (1=1)"
  end

  test "cross join" do
    query =
      from(p in Schema, cross_join: c in Schema2, select: {p.id, c.id})
      |> parse()

    assert query ==
             "SELECT s0.\"id\", s1.\"id\" FROM \"schema\" AS s0 CROSS JOIN \"schema2\" AS s1 ON (1=1)"
  end
end
