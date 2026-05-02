defmodule OberCloud.Providers.Provider do
  @moduledoc """
  Behaviour all infrastructure providers (Hetzner, DigitalOcean, ...) implement.
  """

  @callback validate_credentials(map()) :: :ok | {:error, term()}
  @callback list_regions(map()) :: {:ok, [map()]} | {:error, term()}
  @callback list_server_types(map()) :: {:ok, [map()]} | {:error, term()}
  @callback estimate_cost(map()) :: {:ok, %{monthly_cents: integer(), currency: String.t()}}
end
