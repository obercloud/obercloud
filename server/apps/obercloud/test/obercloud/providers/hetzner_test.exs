defmodule OberCloud.Providers.HetznerTest do
  use ExUnit.Case, async: true
  alias OberCloud.Providers.Hetzner.Adapter

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass, base: "http://localhost:#{bypass.port}/v1"}
  end

  test "validate_credentials returns :ok on 200", %{bypass: bypass, base: base} do
    Bypass.expect_once(bypass, "GET", "/v1/locations", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({"locations":[]}))
    end)
    assert :ok = Adapter.validate_credentials(%{api_token: "x", base_url: base})
  end

  test "validate_credentials returns error on 401", %{bypass: bypass, base: base} do
    Bypass.expect_once(bypass, "GET", "/v1/locations", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(401, ~s({"error":{"message":"unauthorized"}}))
    end)
    assert {:error, _} = Adapter.validate_credentials(%{api_token: "x", base_url: base})
  end

  test "list_regions returns parsed locations", %{bypass: bypass, base: base} do
    Bypass.expect_once(bypass, "GET", "/v1/locations", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({"locations":[{"name":"nbg1","city":"Nuremberg"}]}))
    end)
    assert {:ok, [%{"name" => "nbg1"}]} =
             Adapter.list_regions(%{api_token: "x", base_url: base})
  end
end
