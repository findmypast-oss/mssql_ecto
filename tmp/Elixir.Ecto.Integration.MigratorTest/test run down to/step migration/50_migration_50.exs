defmodule Elixir.Ecto.Integration.MigratorTest.Migration50 do
  use Ecto.Migration

  def up do
    send :"test run down to/step migration", {:up, 50}
  end

  def down do
    send :"test run down to/step migration", {:down, 50}
  end
end
