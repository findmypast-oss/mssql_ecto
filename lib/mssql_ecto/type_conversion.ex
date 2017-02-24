defmodule MssqlEcto.TypeConversion do

  def encode(false, :boolean), do: 0
  def encode(true, :boolean), do: 1
  def encode(value, _type), do: value

  def decode(0, :boolean), do: false
  def decode(1, :boolean), do: true
  def decode(value, _type), do: value
end
