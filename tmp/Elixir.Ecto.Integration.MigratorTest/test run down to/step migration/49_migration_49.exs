defmodule Elixir.Ecto.Integration.MigratorTest.Migration49 do
  use Ecto.Migration

  def up do
    send :"test run down to/step migration", {:up, 49}
  end

  def down do
    send :"test run down to/step migration", {:down, 49}
  end
end
