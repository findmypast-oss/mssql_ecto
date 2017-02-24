defmodule MssqlEcto do
  @moduledoc """
  """

  use Ecto.Adapters.SQL, :mssqlex
  use MssqlEcto.Storage

  import MssqlEcto.TypeConversion, only: [encode: 2, decode: 2]

  def dumpers(:boolean, type), do: [type, &(encode(&1, :boolean))]
  def loaders(:boolean, type), do: [&(decode(&1, :boolean)), type]

end
