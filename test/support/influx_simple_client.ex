defmodule TelemetryInfluxDB.Test.InfluxSimpleClient do
  defmodule V1 do
    def query(config, query) do
      url_encoded = URI.encode_query(%{"q" => query})

      path =
        config.host <>
          ":" <>
          :erlang.integer_to_binary(config.port) <>
          "/query?db=" <> config.db <> "&" <> url_encoded

      headers = authentication_header(config.username, config.password)
      process_response(HTTPoison.get(path, headers))
    end

    def post(config, query) do
      url_encoded = URI.encode_query(%{"q" => query})

      path =
        config.host <>
          ":" <>
          :erlang.integer_to_binary(config.port) <>
          "/query?db=" <> config.db <> "&" <> url_encoded

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

  defmodule V2 do
    def query(config, query) do
      org_encoded = URI.encode_query(%{"org" => config.org})

      body =
        Jason.encode!(%{
          dialect: %{annotations: ["datatype"]},
          query: query
        })

      path =
        config.host <>
          ":" <>
          :erlang.integer_to_binary(config.port) <>
          "/api/v2/query?" <>
          org_encoded

      headers = headers(config)
      process_response(HTTPoison.post(path, body, headers))
    end

    def delete_measurement(%{bucket: bucket, org: org} = config, measurement) do
      # We're required to include a time range, so we create one that
      # should be large enough to capture all of the data while accounting
      # for any clock sync issues between the client and server.
      now = NaiveDateTime.utc_now()
      start = NaiveDateTime.add(now, -3600, :second)
      stop = NaiveDateTime.add(now, 3600, :second)
      predicate = "_measurement=\"#{measurement}\""
      query = URI.encode_query(%{bucket: bucket, org: org})

      body =
        Jason.encode!(%{
          predicate: predicate,
          start: format_time(start),
          stop: format_time(stop)
        })

      path =
        config.host <>
          ":" <>
          :erlang.integer_to_binary(config.port) <>
          "/api/v2/delete?" <>
          query

      headers = headers(config)
      process_response(HTTPoison.post(path, body, headers))
    end

    defp format_time(%NaiveDateTime{} = time) do
      time
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_iso8601()
    end

    defp process_response({:ok, %HTTPoison.Response{body: body}}) do
      body
    end

    defp headers(config) do
      default_headers()
      |> Map.merge(authentication_header(config.token))
    end

    def default_headers() do
      %{
        "Accept" => "application/csv",
        "Content-type" => "application/json"
      }
    end

    defp authentication_header(token) do
      %{"Authorization" => "Token #{token}"}
    end
  end
end
