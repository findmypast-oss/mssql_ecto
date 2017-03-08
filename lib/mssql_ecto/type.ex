defmodule MssqlEcto.Type do
  @bigint_types [:bigint, :integer, :id, :serial]

  def encode(value, :bigint) do
    {:ok, to_string(value)}
  end

  def encode(value, type) do
    {:ok, value}
  end

  # def decode(value, type) when type in @bigint_types do
  #   case Integer.parse(value) do
  #     {int, _} -> {:ok, int}
  #     :error -> {:error, "Not an integer id"}
  #   end
  # end
  def decode(value, :uuid) do
    Ecto.UUID.dump(value)
  end

  def decode({date, {h, m, s}}, type)
  when type in [:utc_datetime, :naive_datetime] do
    {:ok, {date, {h, m, s, 0}}}
  end

  def decode(value, type) do
    IO.inspect {value, type}
    {:ok, value}
  end

end
