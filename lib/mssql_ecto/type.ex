defmodule MssqlEcto.Type do
  @bigint_types [:bigint, :integer, :id, :serial]

  def encode(value, :bigint) do
    {:ok, to_string(value)}
  end

  def encode(value, type) do
    {:ok, value}
  end

  def decode(value, type) when type in @bigint_types do
    case Integer.parse(value) do
      {int, _} -> {:ok, int}
      :error -> {:error, "Not an integer id"}
    end
  end

  def decode(value, type) do
    {:ok, value}
  end

end
