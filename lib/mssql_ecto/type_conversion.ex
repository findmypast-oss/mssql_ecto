defmodule MssqlEcto.TypeConversion do

  def encode(false, :boolean), do: {:ok, 0}
  def encode(true, :boolean), do: {:ok, 1}
  def encode(value, _type), do: value

  def decode(0, :boolean), do: {:ok, false}
  def decode(1, :boolean), do: {:ok, true}
  def decode(value, _type), do: value

  def wrap(value, :integer), do: {:ok, {:sql_integer, [value]}}
  def wrap(value, :naive_datetime), do: {:ok, {:sql_type_timestamp, [value]}}

  def unwrap({_, value}, _), do: {:ok, value}
end
