defmodule MssqlEcto.UpdateTest do
  use MssqlEcto.Case, async: true

  test "update" do
    query =
      SQL.update(nil, "schema", [:x, :y], [:id], [])
      |> IO.iodata_to_binary()

    assert query == ~s{UPDATE "schema" SET "x" = ?, "y" = ? WHERE "id" = ?}

    query =
      SQL.update(nil, "schema", [:x, :y], [:id], [:z])
      |> IO.iodata_to_binary()

    assert query ==
             ~s{UPDATE "schema" SET "x" = ?, "y" = ? OUTPUT INSERTED."z" WHERE "id" = ?}

    query =
      SQL.update("prefix", "schema", [:x, :y], [:id], [])
      |> IO.iodata_to_binary()

    assert query ==
             ~s{UPDATE "prefix"."schema" SET "x" = ?, "y" = ? WHERE "id" = ?}
  end
end
