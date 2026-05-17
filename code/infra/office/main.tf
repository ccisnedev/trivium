locals {
  network_tag   = "trivium-office"
  hostname_fqdn = "${trimsuffix(var.hostname, ".")}."
  startup_script = replace(
    replace(
      replace(
        file("${path.module}/scripts/startup.sh"),
        "__TRIVIUM_ACCESS_MOD_CONF__",
        file("${path.module}/../../mod/trivium_access/mod.conf")
      ),
      "__TRIVIUM_ACCESS_BOOTSTRAP__",
      file("${path.module}/../../mod/trivium_access/bootstrap.lua")
    ),
    "__TRIVIUM_ACCESS_INIT__",
    file("${path.module}/../../mod/trivium_access/init.lua")
  )
}

resource "google_compute_address" "office" {
  name   = "${var.instance_name}-ip"
  region = var.region
}

resource "google_compute_firewall" "luanti" {
  name    = "${var.instance_name}-luanti"
  network = var.network

  allow {
    protocol = "udp"
    ports    = [tostring(var.luanti_port)]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [local.network_tag]
}

resource "google_compute_firewall" "ssh" {
  name    = "${var.instance_name}-ssh"
  network = var.network

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.admin_cidrs
  target_tags   = [local.network_tag]
}

resource "google_compute_instance" "office" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = [local.network_tag]

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-12"
      size  = var.disk_size_gb
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnetwork

    access_config {
      nat_ip = google_compute_address.office.address
    }
  }

  metadata_startup_script = local.startup_script
}

resource "google_dns_record_set" "office" {
  count = var.dns_managed_zone == null ? 0 : 1

  name         = local.hostname_fqdn
  managed_zone = var.dns_managed_zone
  project      = var.project_id
  ttl          = 300
  type         = "A"
  rrdatas      = [google_compute_address.office.address]
}