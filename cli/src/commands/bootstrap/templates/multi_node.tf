terraform {
  required_providers {
    hcloud = { source = "hetznercloud/hcloud", version = "~> 1.48" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

variable "hetzner_token" {}
variable "region" { default = "nbg1" }
variable "server_type" { default = "cx21" }
variable "ssh_pubkey" {}
variable "cluster_name" { default = "obercloud" }

provider "hcloud" { token = var.hetzner_token }

resource "random_password" "db_password" {
  length  = 32
  special = false
}
resource "random_password" "secret_key_base" {
  length  = 64
  special = false
}
resource "random_password" "encryption_key" {
  length  = 32
  special = false
}

resource "hcloud_ssh_key" "boot" {
  name       = "${var.cluster_name}-boot"
  public_key = var.ssh_pubkey
}

# Private network for inter-node traffic (PG replication, libcluster, Horde
# distribution). Without this, replication and BEAM clustering would have
# to traverse the public internet.
resource "hcloud_network" "control_plane" {
  name     = "${var.cluster_name}-network"
  ip_range = "10.42.0.0/16"
}

resource "hcloud_network_subnet" "control_plane" {
  network_id   = hcloud_network.control_plane.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.42.1.0/24"
}

# Three nodes; node 0 is the PG primary, the other two are hot standbys.
# libcluster + Horde handle Elixir node coordination at runtime.
resource "hcloud_server" "control_plane" {
  count       = 3
  name        = "${var.cluster_name}-${count.index + 1}"
  image       = "ubuntu-22.04"
  server_type = var.server_type
  location    = var.region
  ssh_keys    = [hcloud_ssh_key.boot.id]

  labels = {
    obercloud = "control-plane"
    cluster   = var.cluster_name
    role      = count.index == 0 ? "primary" : "standby"
  }

  user_data = templatefile("${path.module}/cloud_init.yaml", {
    db_password     = random_password.db_password.result
    secret_key_base = random_password.secret_key_base.result
    encryption_key  = random_password.encryption_key.result
    provider_token  = var.hetzner_token
    cluster_name    = var.cluster_name
    # Standbys point at node 0 over the private network for PG streaming
    # replication. Node 0 sees itself as the primary.
    primary_host = count.index == 0 ? "127.0.0.1" : "10.42.1.10"
  })
}

resource "hcloud_server_network" "control_plane" {
  count     = 3
  server_id = hcloud_server.control_plane[count.index].id
  subnet_id = hcloud_network_subnet.control_plane.id
  ip        = "10.42.1.${10 + count.index}"
}

output "url" {
  value = "http://${hcloud_server.control_plane[0].ipv4_address}"
}
output "all_ips" {
  value = [for s in hcloud_server.control_plane : s.ipv4_address]
}
output "private_ips" {
  value = [for n in hcloud_server_network.control_plane : n.ip]
}
output "admin_email" { value = "admin@obercloud.local" }
output "admin_password" {
  value     = random_password.db_password.result
  sensitive = true
}
