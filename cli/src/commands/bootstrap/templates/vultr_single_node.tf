terraform {
  required_providers {
    vultr  = { source = "vultr/vultr", version = "~> 2.21" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

variable "vultr_token" {}
variable "region" { default = "ewr" }             # New Jersey
variable "server_type" { default = "vc2-2c-4gb" } # 2 vCPU / 4 GB / $24mo
variable "ssh_pubkey" {}
variable "cluster_name" { default = "obercloud" }

provider "vultr" { api_key = var.vultr_token }

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

# Look up the Ubuntu 22.04 x64 OS id at apply time so we don't hard-code
# the magic number (1743 today, may change).
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

resource "vultr_instance" "control_plane" {
  label       = var.cluster_name
  hostname    = var.cluster_name
  plan        = var.server_type
  region      = var.region
  os_id       = data.vultr_os.ubuntu.id
  ssh_key_ids = [vultr_ssh_key.boot.id]
  enable_ipv6 = false
  tags        = ["obercloud", "control-plane", var.cluster_name]

  user_data = base64encode(templatefile("${path.module}/cloud_init.yaml", {
    db_password     = random_password.db_password.result
    secret_key_base = random_password.secret_key_base.result
    encryption_key  = random_password.encryption_key.result
    provider_token  = var.vultr_token
    cluster_name    = var.cluster_name
    primary_host    = "127.0.0.1"
  }))
}

output "url" { value = "http://${vultr_instance.control_plane.main_ip}" }
output "ip" { value = vultr_instance.control_plane.main_ip }
output "admin_email" { value = "admin@obercloud.local" }
output "admin_password" {
  value     = random_password.db_password.result
  sensitive = true
}
