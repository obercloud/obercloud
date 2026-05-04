defmodule OberCloud.Providers.Vultr.Client do
  @moduledoc "Thin HTTP wrapper around the Vultr API v2."

  @default_base_url "https://api.vultr.com/v2"

  def request(method, path, %{api_token: token} = creds, opts \\ []) do
    base = Map.get(creds, :base_url, @default_base_url)

    case Req.request(
           method: method,
           url: base <> path,
           headers: [{"authorization", "Bearer #{token}"}],
           json: opts[:json]
         ) do
      {:ok, %Req.Response{status: c, body: b}} when c in 200..299 -> {:ok, b}
      {:ok, %Req.Response{status: c, body: b}} -> {:error, {:http, c, b}}
      {:error, r} -> {:error, r}
    end
  end
end
