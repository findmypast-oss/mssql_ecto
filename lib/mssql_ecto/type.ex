defmodule MssqlEcto.Type do
  defmacro is_datetime(type) do
    quote do
      unquote(type) in [
        :naive_datetime,
        :utc_datetime,
        :timestamp
      ]
    end
  end

  def encode(value, :id), do: {:ok, to_string(value)}
  def encode(value, type), do: {:ok, value}

  def decode(value, :id) do
    case Integer.parse(value) do
      {int, _} -> {:ok, int}
      :error -> {:error, "Not an integer id"}
    end
  end
  def decode(value, type) do
    {:ok, value}
  end

end
