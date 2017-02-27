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

  def encode(false, :boolean), do: {:ok, 0}
  def encode(true, :boolean), do: {:ok, 1}
  def encode(value, type) when is_datetime(type) do
    {:ok, NaiveDateTime.to_string(value)}
  end
  def encode(value, _type), do: {:ok, value}

  def decode(0, :boolean), do: {:ok, false}
  def decode(1, :boolean), do: {:ok, true}
  def encode(value, type) when is_datetime(type) do
    NaiveDateTime.from_iso8601(value)
  end
  def decode(value, _type), do: {:ok, value}

  def wrap(value, :integer), do: {:ok, {:sql_integer, [value]}}
  def wrap(value, type) when is_datetime(type), do: {:ok, {{:sql_wvarchar, 27}, [value]}}
  def wrap(value, type), do: {:ok, {type, value}}

  def unwrap({_, value}, _), do: {:ok, value}
end
