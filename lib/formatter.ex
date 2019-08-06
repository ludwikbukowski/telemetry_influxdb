defmodule TelemetryMetricsInfluxDB.Formatter do
  def format(event, measurements, tags \\ %{}) do
    Enum.join(event, ".") <> format_tags(tags) <> format_measurements(measurements)
  end

  defp format_measurements(measurements) do
    " " <> comma_separated(measurements)
  end

  defp format_tags(tags) do
    if tags != %{} do
      "," <> comma_separated(binary_map(tags))
    else
      ""
    end
  end

  defp comma_separated(measurements) do
    measurements
    |> Enum.map(fn {k, v} -> to_bin(k) <> "=" <> to_bin_escaped(v) end)
    |> Enum.join(",")
  end

  defp to_bin(val) when is_integer(val), do: Integer.to_string(val)
  defp to_bin(val) when is_float(val), do: Float.to_string(val)
  defp to_bin(val) when is_atom(val), do: Atom.to_string(val)
  defp to_bin(val), do: val

  defp to_bin_escaped(val) when is_integer(val), do: to_bin(val)
  defp to_bin_escaped(val) when is_float(val), do: to_bin(val)
  defp to_bin_escaped(val) when is_boolean(val), do: to_bin(val)
  defp to_bin_escaped(val), do: "\"" <> to_bin(val) <> "\""

  defp binary_map(atomized_map) do
    Map.new(atomized_map, fn {k, v} -> {to_bin(k), to_bin(v)} end)
  end
end
