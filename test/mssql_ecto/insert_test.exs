defmodule MssqlEcto.InsertTest do
  use MssqlEcto.Case, async: true

  import Ecto.Query

  test "insert" do
    query =
      SQL.insert(nil, "schema", [:x, :y], [[:x, :y]], {:raise, [], []}, [:id])

    assert query ==
             ~s{INSERT INTO "schema" ("x","y") OUTPUT INSERTED."id" VALUES (?1,?2)}

    query =
      SQL.insert(
        nil,
        "schema",
        [:x, :y],
        [[:x, :y], [nil, :z]],
        {:raise, [], []},
        [:id]
      )

    assert query ==
             ~s{INSERT INTO "schema" ("x","y") OUTPUT INSERTED."id" VALUES (?1,?2),(DEFAULT,?3)}

    query = SQL.insert(nil, "schema", [], [[]], {:raise, [], []}, [:id])

    assert query ==
             ~s{INSERT INTO "schema" OUTPUT INSERTED."id" DEFAULT VALUES ; }

    query = SQL.insert(nil, "schema", [], [[]], {:raise, [], []}, [])
    assert query == ~s{INSERT INTO "schema" DEFAULT VALUES ; }

    query = SQL.insert("prefix", "schema", [], [[]], {:raise, [], []}, [])
    assert query == ~s{INSERT INTO "prefix"."schema" DEFAULT VALUES ; }
  end

  @tag skip: "Not yet implemented. Should consider MERGE for upserts"
  test "insert with on conflict" do
    query =
      SQL.insert(nil, "schema", [:x, :y], [[:x, :y]], {:nothing, [], []}, [])

    assert query ==
             ~s{INSERT INTO "schema" ("x","y") VALUES ($1,$2) ON CONFLICT DO NOTHING}

    query =
      SQL.insert(
        nil,
        "schema",
        [:x, :y],
        [[:x, :y]],
        {:nothing, [], [:x, :y]},
        []
      )

    assert query ==
             ~s{INSERT INTO "schema" ("x","y") VALUES ($1,$2) ON CONFLICT ("x","y") DO NOTHING}

    update = from("schema", update: [set: [z: "foo"]]) |> normalize(:update_all)

    query =
      SQL.insert(nil, "schema", [:x, :y], [[:x, :y]], {update, [], [:x, :y]}, [
        :z
      ])

    assert query ==
             ~s{INSERT INTO "schema" AS s0 ("x","y") OUTPUT INSERTED."z" VALUES ($1,$2) ON CONFLICT ("x","y") DO UPDATE SET "z" = 'foo'}

    update =
      from("schema", update: [set: [z: ^"foo"]], where: [w: true])
      |> normalize(:update_all, 2)

    query =
      SQL.insert(nil, "schema", [:x, :y], [[:x, :y]], {update, [], [:x, :y]}, [
        :z
      ])

    assert query ==
             ~s{INSERT INTO "schema" AS s0 ("x","y") OUTPUT INSERTED."z" VALUES ($1,$2) ON CONFLICT ("x","y") DO UPDATE SET "z" = $3 WHERE (s0."w" = TRUE)}

    # For :replace_all
    query =
      SQL.insert(
        nil,
        "schema",
        [:x, :y],
        [[:x, :y]],
        {:replace_all, [], [:id]},
        []
      )

    assert query ==
             ~s{INSERT INTO "schema" ("x","y") VALUES ($1,$2) ON CONFLICT ("id") DO UPDATE SET "x" = EXCLUDED."x","y" = EXCLUDED."y"}

    query =
      SQL.insert(
        nil,
        "schema",
        [:x, :y],
        [[:x, :y]],
        {:replace_all, [], []},
        []
      )

    assert query ==
             ~s{INSERT INTO "schema" ("x","y") VALUES ($1,$2) ON CONFLICT DO UPDATE SET "x" = EXCLUDED."x","y" = EXCLUDED."y"}
  end
end
