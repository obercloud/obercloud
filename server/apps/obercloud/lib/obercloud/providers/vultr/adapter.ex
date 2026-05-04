defmodule OberCloud.Providers.Vultr.Adapter do
  @behaviour OberCloud.Providers.Provider
  alias OberCloud.Providers.Vultr.Client

  @impl true
  def validate_credentials(creds) do
    # GET /v2/account returns 200 with account info on a valid token.
    case Client.request(:get, "/account", creds) do
      {:ok, _} -> :ok
      err -> err
    end
  end

  @impl true
  def list_regions(creds) do
    case Client.request(:get, "/regions", creds) do
      {:ok, %{"regions" => regions}} -> {:ok, regions}
      err -> err
    end
  end

  @impl true
  def list_server_types(creds) do
    case Client.request(:get, "/plans", creds) do
      {:ok, %{"plans" => plans}} -> {:ok, plans}
      err -> err
    end
  end

  @impl true
  def estimate_cost(_spec) do
    # Stubbed flat rate for P0; real pricing in P15.
    # vc2-2c-4gb default = $24/month
    {:ok, %{monthly_cents: 2400, currency: "USD"}}
  end
end
