defmodule MssqlEcto.AlterTableTest do
  use ExUnit.Case, async: true

  import Ecto.Migration, only: [table: 1, table: 2, references: 1, references: 2]

  alias MssqlEcto.Connection, as: SQL
  
  test "alter table" do
    alter = {:alter, table(:posts),
             [{:add, :title, :string, [default: "Untitled", size: 100, null: false]},
              {:add, :author_id, references(:author), []},
              {:modify, :price, :numeric, [precision: 8, scale: 2, null: true]},
              {:modify, :cost, :integer, [null: false, default: nil]},
              {:modify, :permalink_id, references(:permalinks), null: false},
              {:remove, :summary}]}

    assert execute_ddl(alter) == ["""
    ALTER TABLE "posts"
    ADD
    "title" nvarchar(100) DEFAULT 'Untitled' NOT NULL,
    "author_id" bigint CONSTRAINT "posts_author_id_fkey" REFERENCES "author"("id"),
    ALTER COLUMN "price" numeric(8,2),
    ALTER COLUMN "price" DROP NOT NULL,
    ALTER COLUMN "cost" bigint,
    ALTER COLUMN "cost" SET NOT NULL,
    ALTER COLUMN "cost" SET DEFAULT NULL,
    ALTER COLUMN "permalink_id" bigint,
    ADD CONSTRAINT "posts_permalink_id_fkey" FOREIGN KEY ("permalink_id") REFERENCES "permalinks"("id"),
    ALTER COLUMN "permalink_id" SET NOT NULL,
    DROP COLUMN "summary"
    """ |> remove_newlines]
  end

  test "alter table with prefix" do
    alter = {:alter, table(:posts, prefix: :foo),
             [{:add, :author_id, references(:author, prefix: :foo), []},
              {:modify, :permalink_id, references(:permalinks, prefix: :foo), null: false}]}

    assert execute_ddl(alter) == ["""
    ALTER TABLE "foo"."posts"
    ADD "author_id" bigint CONSTRAINT "posts_author_id_fkey" REFERENCES "foo"."author"("id"),
    ALTER COLUMN \"permalink_id\" bigint,
    ADD CONSTRAINT "posts_permalink_id_fkey" FOREIGN KEY ("permalink_id") REFERENCES "foo"."permalinks"("id"),
    ALTER COLUMN "permalink_id" SET NOT NULL
    """ |> remove_newlines]
  end

  test "alter table with primary key" do
    alter = {:alter, table(:posts),
             [{:add, :my_pk, :serial, [primary_key: true]}]}

    assert execute_ddl(alter) == ["""
    ALTER TABLE "posts"
    ADD "my_pk" bigint identity(1,1),
    ADD PRIMARY KEY ("my_pk")
    """ |> remove_newlines]
  end

  defp execute_ddl(command) do
    command |> SQL.execute_ddl() |> Enum.map(&IO.iodata_to_binary/1)
  end
  defp remove_newlines(string) do
    string |> String.trim |> String.replace("\n", " ")
  end
end
