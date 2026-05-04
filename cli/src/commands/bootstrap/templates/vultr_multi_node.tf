terraform {
  required_providers {
    vultr  = { source = "vultr/vultr",   version = "~> 2.21" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

variable "vultr_token"   {}
variable "region"        { default = "ewr" }
variable "server_type"   { default = "vc2-2c-4gb" }
variable "ssh_pubkey"    {}
variable "cluster_name"  { default = "obercloud" }

provider "vultr" { api_key = var.vultr_token }

resource "random_password" "db_password"     { length = 32 ; special = false }
resource "random_password" "secret_key_base" { length = 64 ; special = false }
resource "random_password" "encryption_key"  { length = 32 ; special = false }

data "vultr_os" "ubuntu" {
  filter {
    name   = "name"
    values = ["Ubuntu 22.04 x64"]
  }
}

resource "vultr_ssh_key" "boot" {
  name    = "${var.cluster_name}-boot"
  ssh_key = var.ssh_pubkey
}

# Private network for inter-node traffic. Vultr's vpc2 assigns each
# attached instance a private IP via DHCP. PostgreSQL streaming
# replication still routes over the public IP for P0 (Vultr doesn't
# expose deterministic per-instance private IPs at create time the way
# Hetzner does), but the VPC is provisioned so we can switch to private
# routing in a follow-up without re-bootstrapping.
resource "vultr_vpc2" "control_plane" {
  region        = var.region
  description   = "${var.cluster_name} private network"
  ip_type       = "v4"
  ip_block      = "10.42.1.0"
  prefix_length = 24
}

# Primary node (PG primary, role:primary). Created first so its IP can
# be passed to standbys via cloud-init.
resource "vultr_instance" "primary" {
  label       = "${var.cluster_name}-1"
  hostname    = "${var.cluster_name}-1"
  plan        = var.server_type
  region      = var.region
  os_id       = data.vultr_os.ubuntu.id
  ssh_key_ids = [vultr_ssh_key.boot.id]
  vpc2_ids    = [vultr_vpc2.control_plane.id]
  enable_ipv6 = false
  tags        = ["obercloud", "control-plane", var.cluster_name, "role:primary"]

  user_data = base64encode(templatefile("${path.module}/cloud_init.yaml", {
    db_password     = random_password.db_password.result
    secret_key_base = random_password.secret_key_base.result
    encryption_key  = random_password.encryption_key.result
    provider_token  = var.vultr_token
    cluster_name    = var.cluster_name
    primary_host    = "127.0.0.1"
  }))
}

# Standbys (PG hot standbys, role:standby). Reference the primary's IP
# in cloud-init.
resource "vultr_instance" "standby" {
  count       = 2
  label       = "${var.cluster_name}-${count.index + 2}"
  hostname    = "${var.cluster_name}-${count.index + 2}"
  plan        = var.server_type
  region      = var.region
  os_id       = data.vultr_os.ubuntu.id
  ssh_key_ids = [vultr_ssh_key.boot.id]
  vpc2_ids    = [vultr_vpc2.control_plane.id]
  enable_ipv6 = false
  tags        = ["obercloud", "control-plane", var.cluster_name, "role:standby"]

  user_data = base64encode(templatefile("${path.module}/cloud_init.yaml", {
    db_password     = random_password.db_password.result
    secret_key_base = random_password.secret_key_base.result
    encryption_key  = random_password.encryption_key.result
    provider_token  = var.vultr_token
    cluster_name    = var.cluster_name
    primary_host    = vultr_instance.primary.main_ip
  }))
}

output "url" {
  value = "http://${vultr_instance.primary.main_ip}"
}
output "all_ips" {
  value = concat([vultr_instance.primary.main_ip],
                 [for s in vultr_instance.standby : s.main_ip])
}
output "admin_email"    { value = "admin@obercloud.local" }
output "admin_password" { value = random_password.db_password.result ; sensitive = true }
