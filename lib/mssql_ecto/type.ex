defmodule MssqlEcto.Type do
  @int_types [:bigint, :integer, :id, :serial]
  @decimal_types [:numeric, :decimal]

  def encode(value, :bigint) do
    {:ok, to_string(value)}
  end

  def encode(value, :binary_id) when is_binary(value) do
    Ecto.UUID.load(value)
  end

  def encode(value, :decimal) do
    try do
      value
      |> Decimal.to_integer()
      |> decode(:integer)
    rescue
      _e in FunctionClauseError ->
        {:ok, value}
    end
  end

  def encode(value, _type) do
    {:ok, value}
  end

  def decode(value, type)
      when type in @int_types and is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> {:ok, int}
      :error -> {:error, "Not an integer id"}
    end
  end

  def decode(value, type)
      when type in [:float] do
    cond do
      Decimal.decimal?(value) -> {:ok, Decimal.to_float(value)}
      true -> {:ok, value}
    end
  end

  def decode(value, type)
      when type in @decimal_types and is_binary(value) do
    Decimal.parse(value)
  end

  def decode(value, :uuid) do
    Ecto.UUID.dump(value)
  end

  def decode({date, {h, m, s}}, type)
      when type in [:utc_datetime, :naive_datetime] do
    {:ok, {date, {h, m, s, 0}}}
  end

  def decode(value, type)
      when type in [:date] and is_binary(value) do
    Ecto.Date.cast!(value) |> Ecto.Date.dump()
  end

  def decode(value, _type) do
    {:ok, value}
  end
end
