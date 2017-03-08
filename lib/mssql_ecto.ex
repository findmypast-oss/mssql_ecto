defmodule MssqlEcto do
  @moduledoc """
  """

  use Ecto.Adapters.SQL, :mssqlex
  use MssqlEcto.Storage

  import MssqlEcto.Type, only: [encode: 2, decode: 2]

  def dumpers({:embed, _} = type, _), do: [&Ecto.Adapters.SQL.dump_embed(type, &1)]
  def dumpers(:binary_id, type),      do: [type, Ecto.UUID]
  def dumpers(:uuid, _),              do: []
  def dumpers(ecto_type, type),       do: [type, &(encode(&1, ecto_type))]

  def loaders({:embed, _} = type, _), do: [&Ecto.Adapters.SQL.load_embed(type, &1)]
  # def loaders(:binary_id, type),      do: [Ecto.UUID, type]
  def loaders(ecto_type, type),       do: [&(decode(&1, ecto_type)), type]

end
