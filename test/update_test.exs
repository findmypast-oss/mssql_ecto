defmodule MssqlEcto.UpdateTest do
  use ExUnit.Case, async: true
  @moduletag skip: "pending implementation"

  alias MssqlEcto.Connection, as: SQL
  
  test "update" do
    query = SQL.update(nil, "schema", [:x, :y], [:id], [])
    assert query == ~s{UPDATE "schema" SET "x" = $1, "y" = $2 WHERE "id" = $3}

    query = SQL.update(nil, "schema", [:x, :y], [:id], [:z])
    assert query == ~s{UPDATE "schema" SET "x" = $1, "y" = $2 WHERE "id" = $3 RETURNING "z"}

    query = SQL.update("prefix", "schema", [:x, :y], [:id], [])
    assert query == ~s{UPDATE "prefix"."schema" SET "x" = $1, "y" = $2 WHERE "id" = $3}
  end
end
