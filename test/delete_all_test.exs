defmodule MssqlEcto.DeleteAllTest do
  use ExUnit.Case, async: true
  @moduletag skip: "pending implementation"

  import Ecto.Query

  alias Ecto.Queryable
  alias MssqlEcto.Connection, as: SQL

  defmodule Schema do
    use Ecto.Schema

    schema "schema" do
      field :x, :integer
      field :y, :integer
      field :z, :integer
      field :w, {:array, :integer}

      has_many :comments, MssqlEctoTest.Schema2,
        references: :x,
        foreign_key: :z
      has_one :permalink, MssqlEctoTest.Schema3,
        references: :y,
        foreign_key: :id
    end
  end

  defmodule Schema2 do
    use Ecto.Schema

    schema "schema2" do
      belongs_to :post, MssqlEctoTest.Schema,
        references: :x,
        foreign_key: :z
    end
  end

  defmodule Schema3 do
    use Ecto.Schema

    schema "schema3" do
      field :list1, {:array, :string}
      field :list2, {:array, :integer}
      field :binary, :binary
    end
  end
  
  test "delete all" do
    query = Schema |> Queryable.to_query |> normalize
    assert SQL.delete_all(query) == ~s{DELETE FROM "schema" AS s0}

    query = from(e in Schema, where: e.x == 123) |> normalize
    assert SQL.delete_all(query) ==
           ~s{DELETE FROM "schema" AS s0 WHERE (s0."x" = 123)}

    query = Schema |> join(:inner, [p], q in Schema2, p.x == q.z) |> normalize
    assert SQL.delete_all(query) ==
           ~s{DELETE FROM "schema" AS s0 USING "schema2" AS s1 WHERE (s0."x" = s1."z")}

    query = from(e in Schema, where: e.x == 123, join: q in Schema2, on: e.x == q.z) |> normalize
    assert SQL.delete_all(query) ==
           ~s{DELETE FROM "schema" AS s0 USING "schema2" AS s1 WHERE (s0."x" = s1."z") AND (s0."x" = 123)}

    query = from(e in Schema, where: e.x == 123, join: assoc(e, :comments), join: assoc(e, :permalink)) |> normalize
    assert SQL.delete_all(query) ==
           ~s{DELETE FROM "schema" AS s0 USING "schema2" AS s1, "schema3" AS s2 WHERE (s1."z" = s0."x") AND (s2."id" = s0."y") AND (s0."x" = 123)}
  end

  test "delete all with returning" do
    query = Schema |> Queryable.to_query |> select([m], m) |> normalize
    assert SQL.delete_all(query) == ~s{DELETE FROM "schema" AS s0 RETURNING s0."id", s0."x", s0."y", s0."z", s0."w"}
  end

  test "delete all with prefix" do
    query = Schema |> Queryable.to_query |> normalize
    assert SQL.delete_all(%{query | prefix: "prefix"}) == ~s{DELETE FROM "prefix"."schema" AS s0}
  end

  defp normalize(query, operation \\ :all, counter \\ 0) do
    {query, _params, _key} = Ecto.Query.Planner.prepare(query, operation, MssqlEcto, counter)
    Ecto.Query.Planner.normalize(query, operation, MssqlEcto, counter)
  end
end
