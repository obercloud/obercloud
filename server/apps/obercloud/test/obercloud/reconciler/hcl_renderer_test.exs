defmodule OberCloud.Reconciler.HclRendererTest do
  use ExUnit.Case, async: true
  alias OberCloud.Reconciler.HclRenderer

  test "renders a single Hetzner server resource" do
    spec = %{
      "provider" => "hetzner",
      "resource_type" => "node",
      "name" => "ober-1",
      "region" => "nbg1",
      "server_type" => "cx21",
      "image" => "ubuntu-22.04"
    }

    hcl = HclRenderer.render(spec, "test-token", "control-plane")

    assert hcl =~ ~s(provider "hcloud")
    assert hcl =~ ~s(resource "hcloud_server" "ober_1")
    assert hcl =~ ~s(server_type = "cx21")
    assert hcl =~ ~s(location    = "nbg1")
  end

  test "escapes quotes in attribute values" do
    spec = %{
      "provider" => "hetzner",
      "resource_type" => "node",
      "name" => ~s(a"b),
      "region" => "nbg1",
      "server_type" => "cx21",
      "image" => "ubuntu-22.04"
    }

    hcl = HclRenderer.render(spec, "tok", "ws")
    assert hcl =~ ~s(a\\"b)
  end
end
