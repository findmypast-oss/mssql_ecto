defmodule MssqlEcto.AlterTableTest do
  use MssqlEcto.Case, async: true

  import Ecto.Migration, only: [table: 1, table: 2]
  alias Ecto.Migration.Reference

  test "alter table" do
    alter =
      {:alter, table(:posts),
       [
         {:add, :title, :string, [default: "Untitled", size: 100, null: false]},
         {:add, :author_id, %Reference{table: :author}, []},
         {:modify, :price, :numeric, [precision: 8, scale: 2, null: true]},
         {:modify, :cost, :integer, [null: false, default: nil]},
         {:modify, :permalink_id, %Reference{table: :permalinks}, null: false},
         {:remove, :summary}
       ]}

    assert execute_ddl(alter) == [
             """
             ALTER TABLE "posts"
             ADD
             "title" nvarchar(100) CONSTRAINT "posts_title_default" DEFAULT 'Untitled' NOT NULL,
             "author_id" bigint CONSTRAINT "posts_author_id_fkey" REFERENCES "author"("id");
             ALTER TABLE "posts"
             ALTER COLUMN "price" numeric(8,2) NULL;
             ALTER TABLE "posts"
             ALTER COLUMN "cost" int NOT NULL;
             IF OBJECT_ID('\"posts_cost_default\"', 'D') IS NOT NULL ALTER TABLE \"posts\" DROP CONSTRAINT \"posts_cost_default\";
             ALTER TABLE "posts"
             ADD CONSTRAINT "posts_cost_default" DEFAULT NULL FOR "cost";
             ALTER TABLE "posts"
             ADD CONSTRAINT "posts_permalink_id_fkey" FOREIGN KEY ("permalink_id") REFERENCES "permalinks"("id");
             ALTER TABLE "posts"
             ALTER COLUMN "permalink_id" bigint NOT NULL;
             ALTER TABLE "posts"
             DROP CONSTRAINT "posts_pk";
             ALTER TABLE "posts"
             DROP COLUMN "summary";
             """
             |> remove_newlines
           ]
  end

  test "alter table with prefix" do
    alter =
      {:alter, table(:posts, prefix: :foo),
       [
         {:add, :author_id, %Reference{table: :author}, []},
         {:modify, :permalink_id, %Reference{table: :permalinks}, null: false}
       ]}

    assert execute_ddl(alter) == [
             """
             ALTER TABLE "foo"."posts"
             ADD "author_id" bigint CONSTRAINT "posts_author_id_fkey" REFERENCES "foo"."author"("id");
             ALTER TABLE "foo"."posts"
             ADD CONSTRAINT "posts_permalink_id_fkey" FOREIGN KEY ("permalink_id") REFERENCES "foo"."permalinks"("id");
             ALTER TABLE "foo"."posts"
             ALTER COLUMN "permalink_id" bigint NOT NULL;
             """
             |> remove_newlines
           ]
  end

  test "alter table with primary key" do
    alter =
      {:alter, table(:posts), [{:add, :my_pk, :serial, [primary_key: true]}]}

    assert execute_ddl(alter) == [
             """
             ALTER TABLE "posts"
             ADD "my_pk" int identity(1,1);
             ALTER TABLE "posts"
             ADD CONSTRAINT "posts_pk" PRIMARY KEY ("my_pk");
             """
             |> remove_newlines
           ]
  end

  defp execute_ddl(command) do
    command |> SQL.execute_ddl() |> Enum.map(&IO.iodata_to_binary/1)
  end

  defp remove_newlines(string) do
    string |> String.replace("\n", " ")
  end
end
