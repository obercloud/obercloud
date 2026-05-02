defmodule OberCloud.Providers.Hetzner.Adapter do
  @behaviour OberCloud.Providers.Provider
  alias OberCloud.Providers.Hetzner.Client

  @impl true
  def validate_credentials(creds) do
    case Client.request(:get, "/locations", creds) do
      {:ok, _} -> :ok
      err -> err
    end
  end

  @impl true
  def list_regions(creds) do
    case Client.request(:get, "/locations", creds) do
      {:ok, %{"locations" => locs}} -> {:ok, locs}
      err -> err
    end
  end

  @impl true
  def list_server_types(creds) do
    case Client.request(:get, "/server_types", creds) do
      {:ok, %{"server_types" => types}} -> {:ok, types}
      err -> err
    end
  end

  @impl true
  def estimate_cost(_spec), do: {:ok, %{monthly_cents: 599, currency: "EUR"}}
end
