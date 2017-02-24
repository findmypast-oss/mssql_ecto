defmodule MssqlEcto do
  @moduledoc """
  """

  use Ecto.Adapters.SQL, :mssqlex
  use MssqlEcto.Storage

  import MssqlEcto.TypeConversion, only: [encode: 2, decode: 2]


  def dumpers({:embed, _} = type, _), do: [&Ecto.Adapters.SQL.dump_embed(type, &1)]
  def dumpers(:binary_id, type),      do: [type, Ecto.UUID]
  def dumpers(:boolean, type), do: [type, &(encode(&1, :boolean))]
  def dumpers(_, type),               do: [type]

  def loaders({:embed, _} = type, _), do: [&Ecto.Adapters.SQL.load_embed(type, &1)]
  def loaders(:binary_id, type),      do: [Ecto.UUID, type]
  def loaders(:boolean, type), do: [&(decode(&1, :boolean)), type]
  def loaders(_, type),               do: [type]

end
