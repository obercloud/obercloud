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

resource "hcloud_server" "control_plane" {
  name        = var.cluster_name
  image       = "ubuntu-22.04"
  server_type = var.server_type
  location    = var.region
  ssh_keys    = [hcloud_ssh_key.boot.id]

  labels = {
    obercloud = "control-plane"
    cluster   = var.cluster_name
  }

  user_data = templatefile("${path.module}/cloud_init.yaml", {
    db_password     = random_password.db_password.result
    secret_key_base = random_password.secret_key_base.result
    encryption_key  = random_password.encryption_key.result
    provider_token  = var.hetzner_token
    cluster_name    = var.cluster_name
    primary_host    = "127.0.0.1"
  })
}

output "url" { value = "http://${hcloud_server.control_plane.ipv4_address}" }
output "ip" { value = hcloud_server.control_plane.ipv4_address }
output "admin_email" { value = "admin@obercloud.local" }
output "admin_password" {
  value     = random_password.db_password.result
  sensitive = true
}
