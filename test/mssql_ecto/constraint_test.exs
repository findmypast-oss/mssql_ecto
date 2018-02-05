defmodule MssqlEcto.ConstraintTest do
  use MssqlEcto.Case, async: true

  import Ecto.Migration, only: [constraint: 2, constraint: 3]

  test "create check constraint" do
    create =
      {:create,
       constraint(:products, "price_must_be_positive", check: "price > 0")}

    assert execute_ddl(create) ==
             [
               ~s|ALTER TABLE "products" ADD CONSTRAINT "price_must_be_positive" CHECK (price > 0)|
             ]

    create =
      {:create,
       constraint(
         :products,
         "price_must_be_positive",
         check: "price > 0",
         prefix: "foo"
       )}

    assert execute_ddl(create) ==
             [
               ~s|ALTER TABLE "foo"."products" ADD CONSTRAINT "price_must_be_positive" CHECK (price > 0)|
             ]
  end

  test "create constraint with comment" do
    create =
      {:create,
       constraint(
         :products,
         "price_must_be_positive",
         check: "price > 0",
         prefix: "foo",
         comment: "comment"
       )}

    assert execute_ddl(create) == [
             remove_newlines("""
             ALTER TABLE "foo"."products" ADD CONSTRAINT "price_must_be_positive" CHECK (price > 0)
             """)
           ]
  end

  test "drop constraint" do
    drop = {:drop, constraint(:products, "price_must_be_positive")}

    assert execute_ddl(drop) ==
             [
               ~s|ALTER TABLE "products" DROP CONSTRAINT "price_must_be_positive"|
             ]

    drop =
      {:drop, constraint(:products, "price_must_be_positive", prefix: "foo")}

    assert execute_ddl(drop) ==
             [
               ~s|ALTER TABLE "foo"."products" DROP CONSTRAINT "price_must_be_positive"|
             ]
  end

  defp execute_ddl(command) do
    command |> SQL.execute_ddl() |> Enum.map(&IO.iodata_to_binary/1)
  end

  defp remove_newlines(string) do
    string |> String.trim() |> String.replace("\n", " ")
  end
end
