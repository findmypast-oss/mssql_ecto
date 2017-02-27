defmodule MssqlEcto do
  @moduledoc """
  """

  use Ecto.Adapters.SQL, :mssqlex
  use MssqlEcto.Storage

  import MssqlEcto.Type, only: [encode: 2, decode: 2, wrap: 2, unwrap: 2, is_datetime: 1]

  def dumpers({:embed, _} = type, _), do: [&Ecto.Adapters.SQL.dump_embed(type, &1)]
  def dumpers(:binary_id, type),      do: [type, Ecto.UUID, &(wrap(&1, :binary_id))]
  def dumpers(ecto_type, _) when is_datetime(ecto_type), do: [&(encode(&1, ecto_type)), &(wrap(&1, ecto_type))]
  def dumpers(ecto_type, type),       do: [type, &(encode(&1, ecto_type)), &(wrap(&1, ecto_type))]

  def loaders({:embed, _} = type, _), do: [&Ecto.Adapters.SQL.load_embed(type, &1)]
  def loaders(:binary_id, type),      do: [&(unwrap(&1, :binary_id)), Ecto.UUID, type]
  # def loaders(ecto_type, _) when is_datetime(ecto_type), do: [&(unwrap(&1, ecto_type)), &(decode(&1, ecto_type))]
  def loaders(ecto_type, type),       do: [&(unwrap(&1, ecto_type)), &(decode(&1, ecto_type)), type]

end
