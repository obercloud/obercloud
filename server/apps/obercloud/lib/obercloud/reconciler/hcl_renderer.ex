defmodule OberCloud.Reconciler.HclRenderer do
  @moduledoc "Renders an OberCloud spec into OpenTofu HCL."

  def render(%{"provider" => "hetzner"} = spec, api_token, _ws) do
    name = sanitize(spec["name"])

    """
    terraform {
      required_providers {
        hcloud = { source = "hetznercloud/hcloud", version = "~> 1.48" }
      }
    }

    provider "hcloud" {
      token = "#{escape(api_token)}"
    }

    resource "hcloud_server" "#{name}" {
      name        = "#{escape(spec["name"])}"
      image       = "#{escape(spec["image"])}"
      server_type = "#{escape(spec["server_type"])}"
      location    = "#{escape(spec["region"])}"
    }

    output "ipv4" { value = hcloud_server.#{name}.ipv4_address }
    output "id"   { value = hcloud_server.#{name}.id }
    """
  end

  defp sanitize(name), do: String.replace(name, ~r/[^a-zA-Z0-9_]/, "_")
  defp escape(nil), do: ""
  defp escape(s) when is_binary(s), do: String.replace(s, ~s("), ~s(\\"))
end
