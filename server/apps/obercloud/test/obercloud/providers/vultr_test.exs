defmodule OberCloud.Providers.VultrTest do
  use ExUnit.Case, async: true
  alias OberCloud.Providers.Vultr.Adapter

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass, base: "http://localhost:#{bypass.port}/v2"}
  end

  test "validate_credentials returns :ok on 200", %{bypass: bypass, base: base} do
    Bypass.expect_once(bypass, "GET", "/v2/account", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({"account":{"name":"test"}}))
    end)

    assert :ok = Adapter.validate_credentials(%{api_token: "x", base_url: base})
  end

  test "validate_credentials returns error on 401", %{bypass: bypass, base: base} do
    Bypass.expect_once(bypass, "GET", "/v2/account", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(401, ~s({"error":"Invalid API token"}))
    end)

    assert {:error, _} = Adapter.validate_credentials(%{api_token: "x", base_url: base})
  end

  test "list_regions returns parsed regions", %{bypass: bypass, base: base} do
    Bypass.expect_once(bypass, "GET", "/v2/regions", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({"regions":[{"id":"ewr","city":"New Jersey"}]}))
    end)

    assert {:ok, [%{"id" => "ewr"}]} =
             Adapter.list_regions(%{api_token: "x", base_url: base})
  end

  test "list_server_types returns parsed plans", %{bypass: bypass, base: base} do
    Bypass.expect_once(bypass, "GET", "/v2/plans", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({"plans":[{"id":"vc2-2c-4gb","monthly_cost":24}]}))
    end)

    assert {:ok, [%{"id" => "vc2-2c-4gb"}]} =
             Adapter.list_server_types(%{api_token: "x", base_url: base})
  end
end
