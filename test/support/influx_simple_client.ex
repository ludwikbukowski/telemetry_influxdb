defmodule TelemetryInfluxDB.Test.InfluxSimpleClient do
  def query(config, query) do
    url_encoded = URI.encode_query(%{"q" => query})

    path =
      config.host <>
        ":" <>
        :erlang.integer_to_binary(config.port) <> "/query?db=" <> config.db <> "&" <> url_encoded

    headers = authentication_header(config.username, config.password)
    process_response(HTTPoison.get(path, headers))
  end

  def post(config, query) do
    url_encoded = URI.encode_query(%{"q" => query})

    path =
      config.host <>
        ":" <>
        :erlang.integer_to_binary(config.port) <> "/query?db=" <> config.db <> "&" <> url_encoded

    headers = authentication_header(config.username, config.password)
    process_response(HTTPoison.post(path, "", headers))
  end

  defp process_response({:ok, %HTTPoison.Response{body: body}}) do
    {:ok, res} = Jason.decode(body)
    res
  end

  defp authentication_header(username, password) do
    %{"Authorization" => "Basic #{Base.encode64(username <> ":" <> password)}"}
  end
end
