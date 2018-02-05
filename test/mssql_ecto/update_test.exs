defmodule MssqlEcto.UpdateTest do
  use MssqlEcto.Case, async: true

  test "update" do
    query = SQL.update(nil, "schema", [:x, :y], [:id], [])
    assert query == ~s{UPDATE "schema" SET "x" = ?1, "y" = ?2 WHERE "id" = ?3}

    query = SQL.update(nil, "schema", [:x, :y], [:id], [:z])

    assert query ==
             ~s{UPDATE "schema" SET "x" = ?1, "y" = ?2 OUTPUT INSERTED."z" WHERE "id" = ?3}

    query = SQL.update("prefix", "schema", [:x, :y], [:id], [])

    assert query ==
             ~s{UPDATE "prefix"."schema" SET "x" = ?1, "y" = ?2 WHERE "id" = ?3}
  end
end
