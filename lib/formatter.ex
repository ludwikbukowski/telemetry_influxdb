defmodule TelemetryInfluxDB.Formatter do
  @moduledoc false

  @type tags() :: map()
  @type event_name() :: [atom()]
  @type event_measurements :: map()

  @spec format(event_name(), event_measurements, tags()) :: binary
  def format(event, measurements, tags \\ %{}, timestamp \\ nil) do
    line = Enum.join(event, ".") <> format_tags(tags) <> format_measurements(measurements)

    case timestamp do
      nil -> line
      _ -> line <> " " <> format_timestamp(timestamp)
    end
  end

  defp format_measurements(measurements) do
    " " <> comma_separated(measurements, &to_bin_quoted/1)
  end

  defp format_tags(tags) when tags == %{}, do: ""

  defp format_tags(tags) do
    "," <> comma_separated(tags, &to_bin/1)
  end

  defp format_timestamp(timestamp) when is_integer(timestamp), do: Integer.to_string(timestamp)

  defp format_timestamp(%DateTime{} = timestamp),
    do: DateTime.to_unix(timestamp, :nanosecond) |> Integer.to_string()

  defp comma_separated(map, format_value) do
    map
    |> Enum.map(fn {k, v} -> to_bin(k) <> "=" <> format_value.(v) end)
    |> Enum.join(",")
  end

  defp to_bin(val) when is_integer(val), do: Integer.to_string(val)
  defp to_bin(val) when is_float(val), do: Float.to_string(val)
  defp to_bin(val) when is_atom(val), do: Atom.to_string(val)
  defp to_bin(val) when is_map(val), do: "Unsupported data type"
  defp to_bin(val), do: escape_special_chars(val)

  defp to_bin_quoted(val) when is_integer(val), do: to_bin(val)
  defp to_bin_quoted(val) when is_float(val), do: to_bin(val)
  defp to_bin_quoted(val) when is_boolean(val), do: to_bin(val)
  defp to_bin_quoted(val) when is_map(val), do: "\"" <> to_bin(val) <> "\""
  defp to_bin_quoted(val), do: "\"" <> to_bin(val) <> "\""

  # https://docs.influxdata.com/influxdb/v1.7/write_protocols/line_protocol_tutorial/
  defp escape_special_chars(string) do
    Regex.replace(~r/[=|,| |\"]/, string, fn a, _ -> "\\" <> a end)
  end
end
