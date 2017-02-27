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

  # def encode(false, :boolean), do: {:ok, 0}
  # def encode(true, :boolean), do: {:ok, 1}
  def encode(value, type) when is_datetime(type) do
    {:ok, NaiveDateTime.to_string(value)}
  end
  def encode(value, _type), do: {:ok, value}

  # def decode(0, :boolean), do: {:ok, false}
  # def decode(1, :boolean), do: {:ok, true}
  def decode(value, _type), do: {:ok, value}

  def wrap(value, :id), do: {:ok, {:sql_integer, [value]}}
  def wrap(value, :binary_id), do: {:ok, {{:sql_char, 36}, [value]}}
  def wrap(value, :integer), do: {:ok, {:sql_integer, [value]}}
  def wrap(value, :float), do: {:ok, {:sql_float, [value]}}
  def wrap(value, :boolean), do: {:ok, {:sql_bit, [value]}}
  def wrap(value, :string), do: {:ok, {{:sql_wvarchar, String.length(value)}, [value]}}
  def wrap(value, :binary), do: {:ok, {:sql_binary, [value]}}
  def wrap(value, :decimal), do: {:ok, {{:sql_decimal, Map.get(Decimal.get_context(), :precision), 0}, [value]}}
  def wrap(value, :date), do: {:ok, {:sql_type_date, [value]}}
  def wrap(value, :time), do: {:ok, {:sql_type_time, [value]}}
  def wrap(value, type) when is_datetime(type), do: {:ok, {{:sql_wvarchar, 27}, [value]}}
  def wrap(value, type), do: {:ok, {type, value}}

  def unwrap({_, value}, _), do: {:ok, value}
end
