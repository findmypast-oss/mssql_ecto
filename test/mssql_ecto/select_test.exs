defmodule MssqlEcto.SelectTest do
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

  defp parse(query) do
    query |> normalize |> SQL.all() |> IO.iodata_to_binary()
  end

  test "from" do
    query = Schema |> select([r], r.x) |> parse()
    assert query == ~s{SELECT s0."x" FROM "schema" AS s0}
  end

  test "from without schema" do
    query = "posts" |> select([r], r.x) |> parse()
    assert query == ~s{SELECT p0."x" FROM "posts" AS p0}

    query = "posts" |> select([:x]) |> parse()
    assert query == ~s{SELECT p0."x" FROM "posts" AS p0}

    assert_raise Ecto.QueryError,
                 ~r"Microsoft SQL Server requires a schema module",
                 fn ->
                   SQL.all(from(p in "posts", select: p) |> normalize())
                 end
  end

  test "from with subquery" do
    query =
      subquery("posts" |> select([r], %{x: r.x, y: r.y}))
      |> select([r], r.x)
      |> parse()

    assert query ==
             ~s{SELECT s0."x" FROM (SELECT p0."x" AS "x", p0."y" AS "y" FROM "posts" AS p0) AS s0}

    query =
      subquery("posts" |> select([r], %{x: r.x, z: r.y}))
      |> select([r], r)
      |> parse()

    assert query ==
             ~s{SELECT s0."x", s0."z" FROM (SELECT p0."x" AS "x", p0."y" AS "z" FROM "posts" AS p0) AS s0}
  end

  test "select" do
    query = Schema |> select([r], {r.x, r.y}) |> parse()
    assert query == ~s{SELECT s0."x", s0."y" FROM "schema" AS s0}

    query = Schema |> select([r], [r.x, r.y]) |> parse()
    assert query == ~s{SELECT s0."x", s0."y" FROM "schema" AS s0}

    query =
      Schema
      |> select([r], struct(r, [:x, :y]))
      |> parse()

    assert query == ~s{SELECT s0."x", s0."y" FROM "schema" AS s0}
  end

  test "aggregates" do
    query = Schema |> select([r], count(r.x)) |> parse()
    assert query == ~s{SELECT count(s0."x") FROM "schema" AS s0}

    query =
      Schema
      |> select([r], count(r.x, :distinct))
      |> parse()

    assert query ==
             ~s{SELECT count(DISTINCT s0."x") FROM "schema" AS s0}
  end

  test "distinct" do
    query =
      Schema
      |> distinct([r], r.x)
      |> select([r], {r.x, r.y})
      |> parse()

    assert query ==
             ~s{SELECT DISTINCT ON (s0."x") s0."x", s0."y" FROM "schema" AS s0}

    query =
      Schema
      |> distinct([r], desc: r.x)
      |> select([r], {r.x, r.y})
      |> parse()

    assert query ==
             ~s{SELECT DISTINCT ON (s0."x") s0."x", s0."y" FROM "schema" AS s0}

    query =
      Schema
      |> distinct([r], 2)
      |> select([r], r.x)
      |> parse()

    assert query ==
             ~s{SELECT DISTINCT ON (2) s0."x" FROM "schema" AS s0}

    query =
      Schema
      |> distinct([r], [r.x, r.y])
      |> select([r], {r.x, r.y})
      |> parse()

    assert query ==
             ~s{SELECT DISTINCT ON (s0."x", s0."y") s0."x", s0."y" FROM "schema" AS s0}

    query =
      Schema
      |> distinct([r], true)
      |> select([r], {r.x, r.y})
      |> parse()

    assert query ==
             ~s{SELECT DISTINCT s0."x", s0."y" FROM "schema" AS s0}

    query =
      Schema
      |> distinct([r], false)
      |> select([r], {r.x, r.y})
      |> parse()

    assert query == ~s{SELECT s0."x", s0."y" FROM "schema" AS s0}

    query =
      Schema
      |> distinct(true)
      |> select([r], {r.x, r.y})
      |> parse()

    assert query ==
             ~s{SELECT DISTINCT s0."x", s0."y" FROM "schema" AS s0}

    query =
      Schema
      |> distinct(false)
      |> select([r], {r.x, r.y})
      |> parse()

    assert query == ~s{SELECT s0."x", s0."y" FROM "schema" AS s0}
  end

  test "distinct with order by" do
    query =
      Schema
      |> order_by([r], [r.y])
      |> distinct([r], desc: r.x)
      |> select([r], r.x)
      |> parse()

    assert query ==
             ~s{SELECT DISTINCT ON (s0."x") s0."x" FROM "schema" AS s0 ORDER BY s0."x" DESC, s0."y"}
  end

  test "where" do
    query =
      Schema
      |> where([r], r.x == 42)
      |> where([r], r.y != 43)
      |> select([r], r.x)
      |> parse()

    assert query ==
             ~s{SELECT s0."x" FROM "schema" AS s0 WHERE (s0."x" = 42) AND (s0."y" != 43)}
  end

  test "or_where" do
    query =
      Schema
      |> or_where([r], r.x == 42)
      |> or_where([r], r.y != 43)
      |> select([r], r.x)
      |> parse()

    assert query ==
             ~s{SELECT s0."x" FROM "schema" AS s0 WHERE (s0."x" = 42) OR (s0."y" != 43)}

    query =
      Schema
      |> or_where([r], r.x == 42)
      |> or_where([r], r.y != 43)
      |> where([r], r.z == 44)
      |> select([r], r.x)
      |> parse()

    assert query ==
             ~s{SELECT s0."x" FROM "schema" AS s0 WHERE ((s0."x" = 42) OR (s0."y" != 43)) AND (s0."z" = 44)}
  end

  test "order by" do
    query =
      Schema
      |> order_by([r], r.x)
      |> select([r], r.x)
      |> parse()

    assert query ==
             ~s{SELECT s0."x" FROM "schema" AS s0 ORDER BY s0."x"}

    query =
      Schema
      |> order_by([r], [r.x, r.y])
      |> select([r], r.x)
      |> parse()

    assert query ==
             ~s{SELECT s0."x" FROM "schema" AS s0 ORDER BY s0."x", s0."y"}

    query =
      Schema
      |> order_by([r], asc: r.x, desc: r.y)
      |> select([r], r.x)
      |> parse()

    assert query ==
             ~s{SELECT s0."x" FROM "schema" AS s0 ORDER BY s0."x", s0."y" DESC}

    query =
      Schema
      |> order_by([r], [])
      |> select([r], r.x)
      |> parse()

    assert query == ~s{SELECT s0."x" FROM "schema" AS s0}
  end

  test "limit and offset" do
    query =
      Schema
      |> limit([r], 3)
      |> select([], true)
      |> parse()

    assert query == ~s{SELECT TOP 3 'TRUE' FROM "schema" AS s0}

    query =
      Schema
      |> offset([r], 5)
      |> select([], true)
      |> parse()

    assert query == ~s{SELECT 'TRUE' FROM "schema" AS s0 OFFSET 5 ROWS}

    query =
      Schema
      |> offset([r], 5)
      |> limit([r], 3)
      |> select([], true)
      |> parse()

    assert query ==
             ~s{SELECT 'TRUE' FROM "schema" AS s0 OFFSET 5 ROWS FETCH NEXT 3 ROWS ONLY}
  end

  # TODO why was this skipped?
  #@tag skip: "Not yet supported"
  test "lock" do
    query =
      Schema
      |> lock("FOR SHARE NOWAIT")
      |> select([], true)
      |> parse()

    assert query ==
             ~s{SELECT 'TRUE' FROM "schema" AS s0 FOR SHARE NOWAIT}
  end

  test "string escape" do
    query =
      "schema"
      |> where(foo: "'\\  ")
      |> select([], true)
      |> parse()

    assert query ==
             ~s{SELECT 'TRUE' FROM \"schema\" AS s0 WHERE (s0.\"foo\" = '''\\  ')}

    query =
      "schema"
      |> where(foo: "'")
      |> select([], true)
      |> parse()

    assert query ==
             ~s{SELECT 'TRUE' FROM "schema" AS s0 WHERE (s0."foo" = '''')}
  end

  test "binary ops" do
    query = Schema |> select([r], r.x == 2) |> parse()
    assert query == ~s{SELECT s0."x" = 2 FROM "schema" AS s0}

    query = Schema |> select([r], r.x != 2) |> parse()
    assert query == ~s{SELECT s0."x" != 2 FROM "schema" AS s0}

    query = Schema |> select([r], r.x <= 2) |> parse()
    assert query == ~s{SELECT s0."x" <= 2 FROM "schema" AS s0}

    query = Schema |> select([r], r.x >= 2) |> parse()
    assert query == ~s{SELECT s0."x" >= 2 FROM "schema" AS s0}

    query = Schema |> select([r], r.x < 2) |> parse()
    assert query == ~s{SELECT s0."x" < 2 FROM "schema" AS s0}

    query = Schema |> select([r], r.x > 2) |> parse()
    assert query == ~s{SELECT s0."x" > 2 FROM "schema" AS s0}
  end

  test "is_nil" do
    query = Schema |> select([r], is_nil(r.x)) |> parse()
    assert query == ~s{SELECT s0."x" IS NULL FROM "schema" AS s0}

    query = Schema |> select([r], not is_nil(r.x)) |> parse()

    assert query == ~s{SELECT ~(s0."x" IS NULL) FROM "schema" AS s0}
  end

  test "fragments" do
    query = Schema |> select([r], fragment("now")) |> parse()

    assert query == ~s{SELECT now FROM "schema" AS s0}

    query =
      Schema
      |> select([r], fragment("downcase(?)", r.x))
      |> parse()

    assert query == ~s{SELECT downcase(s0."x") FROM "schema" AS s0}

    value = 13

    query =
      Schema
      |> select([r], fragment("downcase(?, ?)", r.x, ^value))
      |> parse()

    assert query == ~s{SELECT downcase(s0."x", ?) FROM "schema" AS s0}

    query = Schema |> select([], fragment(title: 2))

    assert_raise Ecto.QueryError, fn ->
     parse(query)
    end
  end

  test "literals" do
    query =
      "schema"
      |> where(foo: true)
      |> select([], true)
      |> parse()

    assert query ==
             ~s{SELECT 'TRUE' FROM "schema" AS s0 WHERE (s0."foo" = 1)}

    query =
      "schema"
      |> where(foo: false)
      |> select([], true)
      |> parse()

    assert query ==
             ~s{SELECT 'TRUE' FROM "schema" AS s0 WHERE (s0."foo" = 0)}

    query =
      "schema"
      |> where(foo: "abc")
      |> select([], true)
      |> parse()

    assert query ==
             ~s{SELECT 'TRUE' FROM "schema" AS s0 WHERE (s0."foo" = 'abc')}

    query =
      "schema"
      |> where(foo: <<0, ?a, ?b, ?c>>)
      |> select([], true)
      |> parse()

    assert query ==
             ~s{SELECT 'TRUE' FROM "schema" AS s0 WHERE (s0."foo" = 0x00616263)}

    query =
      "schema"
      |> where(foo: 123)
      |> select([], true)
      |> parse()

    assert query ==
             ~s{SELECT 'TRUE' FROM "schema" AS s0 WHERE (s0."foo" = 123)}

    query =
      "schema"
      |> where(foo: 123.0)
      |> select([], true)
      |> parse()

    assert query ==
             ~s{SELECT 'TRUE' FROM "schema" AS s0 WHERE (s0."foo" = 123.0)}
  end

  test "tagged type" do
    query =
      Schema
      |> select([], type(^"601d74e4-a8d3-4b6e-8365-eddb4c893327", Ecto.UUID))
      |> parse()

    assert query == ~s{SELECT CAST(? AS char(36)) FROM "schema" AS s0}

    query =
      Schema
      |> select([], type(^1, Custom.Permalink))
      |> parse()

    assert query == ~s{SELECT CAST(? AS int) FROM "schema" AS s0}
  end

  test "nested expressions" do
    z = 123

    query =
      from(r in Schema, [])
      |> select([r], (r.x > 0 and r.y > ^(-z)) or true)
      |> parse()

    assert query ==
             ~s{SELECT ((s0."x" > 0) AND (s0."y" > ?)) OR 1 FROM "schema" AS s0}
  end

  test "in expression" do
    query = Schema |> select([e], 1 in []) |> parse()
    assert query == ~s{SELECT 0=1 FROM "schema" AS s0}

    query = Schema |> select([e], 1 in [1, e.x, 3]) |> parse()

    assert query == ~s{SELECT 1 IN (1,s0."x",3) FROM "schema" AS s0}

    query = Schema |> select([e], 1 in ^[]) |> parse()
    assert query == ~s{SELECT 0=1 FROM "schema" AS s0}

    query = Schema |> select([e], 1 in ^[1, 2, 3]) |> parse()

    assert query == ~s{SELECT 1 IN (?,?,?) FROM "schema" AS s0}

    query = Schema |> select([e], 1 in [1, ^2, 3]) |> parse()

    assert query == ~s{SELECT 1 IN (1,?,3) FROM "schema" AS s0}

    query = Schema |> select([e], ^1 in [1, ^2, 3]) |> parse()

    assert query == ~s{SELECT ? IN (1,?,3) FROM "schema" AS s0}

    query = Schema |> select([e], ^1 in ^[1, 2, 3]) |> parse()

    assert query == ~s{SELECT ? IN (?,?,?) FROM "schema" AS s0}

    query = Schema |> select([e], 1 in e.w) |> parse()
    assert query == ~s{SELECT 1 = ANY(s0."w") FROM "schema" AS s0}

    query =
      Schema
      |> select([e], 1 in fragment("foo"))
      |> parse()

    assert query == ~s{SELECT 1 = ANY(foo) FROM "schema" AS s0}
  end

  test "having" do
    query =
      Schema
      |> having([p], p.x == p.x)
      |> select([], true)
      |> parse()

    assert query ==
             ~s{SELECT 'TRUE' FROM "schema" AS s0 HAVING (s0."x" = s0."x")}

    query =
      Schema
      |> having([p], p.x == p.x)
      |> having([p], p.y == p.y)
      |> select([], true)
      |> parse()

    assert query ==
             ~s{SELECT 'TRUE' FROM "schema" AS s0 HAVING (s0."x" = s0."x") AND (s0."y" = s0."y")}
  end

  test "or_having" do
    query =
      Schema
      |> or_having([p], p.x == p.x)
      |> select([], true)
      |> parse()

    assert query ==
             ~s{SELECT 'TRUE' FROM "schema" AS s0 HAVING (s0."x" = s0."x")}

    query =
      Schema
      |> or_having([p], p.x == p.x)
      |> or_having([p], p.y == p.y)
      |> select([], true)
      |> parse()

    assert query ==
             ~s{SELECT 'TRUE' FROM "schema" AS s0 HAVING (s0."x" = s0."x") OR (s0."y" = s0."y")}
  end

  test "group by" do
    query =
      Schema
      |> group_by([r], r.x)
      |> select([r], r.x)
      |> parse()

    assert query ==
             ~s{SELECT s0."x" FROM "schema" AS s0 GROUP BY s0."x"}

    query =
      Schema
      |> group_by([r], 2)
      |> select([r], r.x)
      |> parse()

    assert query == ~s{SELECT s0."x" FROM "schema" AS s0 GROUP BY 2}

    query =
      Schema
      |> group_by([r], [r.x, r.y])
      |> select([r], r.x)
      |> parse()

    assert query ==
             ~s{SELECT s0."x" FROM "schema" AS s0 GROUP BY s0."x", s0."y"}

    query =
      Schema
      |> group_by([r], [])
      |> select([r], r.x)
      |> parse()

    assert query == ~s{SELECT s0."x" FROM "schema" AS s0}
  end

  test "arrays and sigils" do
    query =
      Schema
      |> select([], fragment("?", [1, 2, 3]))
      |> parse()

    assert query == ~s{SELECT ARRAY[1,2,3] FROM "schema" AS s0}

    query =
      Schema
      |> select([], fragment("?", ~w(abc def)))
      |> parse()

    assert query == ~s{SELECT ARRAY['abc','def'] FROM "schema" AS s0}
  end

  test "interpolated values" do
    query =
      "schema"
      |> select([m], {m.id, ^true})
      |> join(:inner, [], Schema2, on: fragment("?", ^true))
      |> join(:inner, [], Schema2, on: fragment("?", ^false))
      |> where([], fragment("?", ^true))
      |> where([], fragment("?", ^false))
      |> having([], fragment("?", ^true))
      |> having([], fragment("?", ^false))
      |> group_by([], fragment("?", ^1))
      |> group_by([], fragment("?", ^2))
      |> order_by([], fragment("?", ^3))
      |> order_by([], ^:x)
      |> limit([], ^4)
      |> offset([], ^5)
      |> parse()

    result =
      ~s/SELECT s0."id", ? FROM "schema" AS s0 INNER JOIN "schema2" AS s1 ON (?) / <>
        ~s/INNER JOIN "schema2" AS s2 ON (?) WHERE (?) AND (?) / <>
        ~s/GROUP BY ?, ? HAVING (?) AND (?) / <>
        ~s/ORDER BY ?, s0."x" OFFSET ? ROWS FETCH NEXT ? ROWS ONLY/

    assert query == String.trim(result)
  end

  test "fragments and types" do
    query =
      from(
        e in "schema",
        where:
          fragment(
            "extract(? from ?) = ?",
            ^"month",
            e.start_time,
            type(^"4", :integer)
          ),
        where:
          fragment(
            "extract(? from ?) = ?",
            ^"year",
            e.start_time,
            type(^"2015", :integer)
          ),
        select: true
      )
      |> parse()

    result =
      "SELECT 'TRUE' FROM \"schema\" AS s0 " <>
        "WHERE (extract(? from s0.\"start_time\") = CAST(? AS int)) " <>
        "AND (extract(? from s0.\"start_time\") = CAST(? AS int))"

    assert query == String.trim(result)
  end

  test "fragments allow ? to be escaped with backslash" do
    query =
      from(
        e in "schema",
        where: fragment("? = \"query\\?\"", e.start_time),
        select: true
      )
      |> parse()

    result =
      "SELECT 'TRUE' FROM \"schema\" AS s0 " <>
        "WHERE (s0.\"start_time\" = \"query?\")"

    assert query == String.trim(result)
  end
end
