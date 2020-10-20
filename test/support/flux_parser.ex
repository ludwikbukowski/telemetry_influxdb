defmodule TelemetryInfluxDB.Test.FluxParser do
  alias NimbleCSV.RFC4180, as: CSV

  @column_types %{
    "boolean" => :boolean,
    "double" => :double,
    "string" => :string,
    "long" => :long,
    "unsignedLong" => :unsigned_long,
    "dateTime:RFC3339" => :datetime
  }

  def parse_tables(csv) do
    csv
    |> extract_chunks()
    |> Enum.flat_map(&parse_chunk/1)
  end

  def extract_chunks(csv) do
    csv
    |> String.trim()
    |> String.split(~r/\n\s*\n/)
  end

  def parse_chunk(chunk) do
    {annotations, data} =
      chunk
      |> String.split("\n")
      |> Enum.split_with(&is_annotation?/1)

    table_data = data |> parse_lines() |> separate_tables()
    column_types = annotations |> parse_lines() |> get_column_types()

    Enum.flat_map(table_data, &parse_table(&1, column_types))
  end

  defp is_annotation?(line) do
    String.starts_with?(line, "#")
  end

  defp parse_lines(lines) do
    lines
    |> Enum.join("\n")
    |> String.trim()
    |> parse_csv()
  end

  defp separate_tables(parsed) when parsed == [], do: [[]]

  defp separate_tables([headers | rows]) do
    table_index = Enum.find_index(headers, fn header -> header == "table" end)

    rows
    |> Enum.chunk_by(fn row -> Enum.at(row, table_index) end)
    |> Enum.map(fn table_rows -> List.insert_at(table_rows, 0, headers) end)
  end

  def get_column_types([]), do: []

  def get_column_types(annotation_data) do
    col_types_index =
      annotation_data
      |> Enum.find_index(fn a -> List.first(a) == "#datatype" end)

    annotation_data
    |> Enum.at(col_types_index)
  end

  defp parse_table(table, _column_types) when length(table) == 0, do: %{}

  defp parse_table(table, column_types) do
    [column_names | table_rows] = table
    parse_rows(table_rows, column_names, column_types)
  end

  defp parse_rows(
         table,
         [_datatype | column_names],
         [_ | column_types]
       ) do
    Enum.map(table, fn [_empty | row] -> parse_row(row, column_types, column_names) end)
  end

  defp parse_row(row, types, columns) do
    [types, columns, row]
    |> Enum.zip()
    |> Enum.map(fn column_info -> type_value(column_info) end)
    |> Enum.into(%{})
  end

  defp type_value({raw_type, column, value}) do
    type = Map.get(@column_types, raw_type)
    typed_value = parse_value(value, type)
    {column, typed_value}
  end

  def parse_value("null", _type), do: nil

  def parse_value("true", :boolean), do: true
  def parse_value("false", :boolean), do: false

  def parse_value(string, :string), do: string

  def parse_value("NaN", :double), do: NaN

  def parse_value(string, :double) do
    case Float.parse(string) do
      {value, _} -> value
      :error -> raise ArgumentError, "invalid double argument: '#{string}'"
    end
  end

  def parse_value(datetime, :datetime) do
    case DateTime.from_iso8601(datetime) do
      {:ok, datetime, _offset} -> %{datetime | microsecond: {0, 6}}
      {:error, _} -> raise ArgumentError, "invalid datetime argument: '#{datetime}'"
    end
  end

  def parse_value(raw, :unsigned_long) do
    value = parse_integer(raw)

    if value < 0 do
      raise ArgumentError, message: "invalid unsigned_long argument: '#{value}'"
    end

    value
  end

  def parse_value(raw, :long), do: parse_integer(raw)

  defp parse_integer("NaN"), do: NaN

  defp parse_integer(raw) do
    {value, _} = Integer.parse(raw, 10)

    value
  end

  def parse_csv(csv) do
    CSV.parse_string(csv, skip_headers: false)
  end
end
