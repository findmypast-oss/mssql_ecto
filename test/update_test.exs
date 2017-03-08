defmodule MssqlEcto.UpdateTest do
  use ExUnit.Case, async: true

  alias MssqlEcto.Connection, as: SQL
  
  test "update" do
    query = SQL.update(nil, "schema", [:x, :y], [:id], [])
    assert query == ~s{UPDATE "schema" SET "x" = ?, "y" = ? WHERE "id" = ?}

    query = SQL.update(nil, "schema", [:x, :y], [:id], [:z])
    assert query == ~s{UPDATE "schema" SET "x" = ?, "y" = ? WHERE "id" = ? OUTPUT INSERTED."z"}

    query = SQL.update("prefix", "schema", [:x, :y], [:id], [])
    assert query == ~s{UPDATE "prefix"."schema" SET "x" = ?, "y" = ? WHERE "id" = ?}
  end
end
