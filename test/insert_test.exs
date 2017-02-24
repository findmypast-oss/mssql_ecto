defmodule MssqlEcto.InsertTest do
  use ExUnit.Case, async: true
  @moduletag skip: "pending implementation"

  import Ecto.Query

  alias MssqlEcto.Connection, as: SQL
  
  test "insert" do
    query = SQL.insert(nil, "schema", [:x, :y], [[:x, :y]], {:raise, [], []}, [:id])
    assert query == ~s{INSERT INTO "schema" ("x","y") VALUES (?,?) RETURNING "id"}

    query = SQL.insert(nil, "schema", [:x, :y], [[:x, :y], [nil, :z]], {:raise, [], []}, [:id])
    assert query == ~s{INSERT INTO "schema" ("x","y") VALUES (?,?),(DEFAULT,?) RETURNING "id"}

    query = SQL.insert(nil, "schema", [], [[]], {:raise, [], []}, [:id])
    assert query == ~s{INSERT INTO "schema" VALUES (DEFAULT) RETURNING "id"}

    query = SQL.insert(nil, "schema", [], [[]], {:raise, [], []}, [])
    assert query == ~s{INSERT INTO "schema" VALUES (DEFAULT)}

    query = SQL.insert("prefix", "schema", [], [[]], {:raise, [], []}, [])
    assert query == ~s{INSERT INTO "prefix"."schema" VALUES (DEFAULT)}
  end

  @tag skip: "Not yet implemented. Should consider MERGE for upserts"
  test "insert with on conflict" do
    query = SQL.insert(nil, "schema", [:x, :y], [[:x, :y]], {:nothing, [], []}, [])
    assert query == ~s{INSERT INTO "schema" ("x","y") VALUES ($1,$2) ON CONFLICT DO NOTHING}

    query = SQL.insert(nil, "schema", [:x, :y], [[:x, :y]], {:nothing, [], [:x, :y]}, [])
    assert query == ~s{INSERT INTO "schema" ("x","y") VALUES ($1,$2) ON CONFLICT ("x","y") DO NOTHING}

    update = from("schema", update: [set: [z: "foo"]]) |> normalize(:update_all)
    query = SQL.insert(nil, "schema", [:x, :y], [[:x, :y]], {update, [], [:x, :y]}, [:z])
    assert query == ~s{INSERT INTO "schema" AS s0 ("x","y") VALUES ($1,$2) ON CONFLICT ("x","y") DO UPDATE SET "z" = 'foo' RETURNING "z"}

    update = from("schema", update: [set: [z: ^"foo"]], where: [w: true]) |> normalize(:update_all, 2)
    query = SQL.insert(nil, "schema", [:x, :y], [[:x, :y]], {update, [], [:x, :y]}, [:z])
    assert query == ~s{INSERT INTO "schema" AS s0 ("x","y") VALUES ($1,$2) ON CONFLICT ("x","y") DO UPDATE SET "z" = $3 WHERE (s0."w" = TRUE) RETURNING "z"}

    # For :replace_all
    query = SQL.insert(nil, "schema", [:x, :y], [[:x, :y]], {:replace_all, [], [:id]}, [])
    assert query == ~s{INSERT INTO "schema" ("x","y") VALUES ($1,$2) ON CONFLICT ("id") DO UPDATE SET "x" = EXCLUDED."x","y" = EXCLUDED."y"}

    query = SQL.insert(nil, "schema", [:x, :y], [[:x, :y]], {:replace_all, [], []}, [])
    assert query == ~s{INSERT INTO "schema" ("x","y") VALUES ($1,$2) ON CONFLICT DO UPDATE SET "x" = EXCLUDED."x","y" = EXCLUDED."y"}
  end

  defp normalize(query, operation, counter \\ 0) do
    {query, _params, _key} = Ecto.Query.Planner.prepare(query, operation, MssqlEcto, counter)
    Ecto.Query.Planner.normalize(query, operation, MssqlEcto, counter)
  end
end
