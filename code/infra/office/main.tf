locals {
  network_tag            = "trivium-office"
  hostname_fqdn          = "${trimsuffix(var.hostname, ".")}."
  world_disk_name        = "${var.instance_name}-world-data"
  luanti_bundle_is_gcs   = var.luanti_bundle_url != null && startswith(var.luanti_bundle_url, "gs://")
  luanti_bundle_parts    = local.luanti_bundle_is_gcs ? split("/", trimprefix(var.luanti_bundle_url, "gs://")) : []
  luanti_bundle_bucket   = local.luanti_bundle_is_gcs ? local.luanti_bundle_parts[0] : null
  startup_script = replace(
    replace(
      file("${path.module}/scripts/startup.sh"),
      "__WORLD_DISK_DEVICE__",
      "/dev/disk/by-id/google-${local.world_disk_name}"
    ),
    "__LUANTI_SERVER_BUNDLE_URL__",
    var.luanti_bundle_url == null ? "" : var.luanti_bundle_url
  )
  worldmods_fingerprint = sha256(join("", [
    filesha256("${path.module}/../../mod/trivium_access/mod.conf"),
    filesha256("${path.module}/../../mod/trivium_access/bootstrap.lua"),
    filesha256("${path.module}/../../mod/trivium_access/init.lua"),
    filesha256("${path.module}/../../mod/trivium/mod.conf"),
    filesha256("${path.module}/../../mod/trivium/init.lua"),
    filesha256("${path.module}/scripts/deploy-worldmods.ps1"),
  ]))
}

resource "terraform_data" "bootstrap_config" {
  triggers_replace = {
    startup_script_hash = sha256(local.startup_script)
  }
}

resource "google_compute_address" "office" {
  name   = "${var.instance_name}-ip"
  region = var.region
}

resource "google_service_account" "office_vm" {
  project      = var.project_id
  account_id   = "office-server-vm"
  display_name = "Trivium Office VM"
}

resource "google_storage_bucket_iam_member" "office_vm_bundle_reader" {
  count = local.luanti_bundle_is_gcs ? 1 : 0

  bucket = local.luanti_bundle_bucket
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.office_vm.email}"
}

resource "google_compute_disk" "office_world" {
  name = local.world_disk_name
  type = "pd-ssd"
  zone = var.zone
  size = var.world_disk_size_gb
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

  service_account {
    email  = google_service_account.office_vm.email
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only"]
  }

  lifecycle {
    ignore_changes       = [attached_disk]
    replace_triggered_by = [terraform_data.bootstrap_config]
  }

  depends_on = [google_storage_bucket_iam_member.office_vm_bundle_reader]
}

resource "google_compute_attached_disk" "office_world" {
  disk        = google_compute_disk.office_world.name
  instance    = google_compute_instance.office.name
  zone        = var.zone
  device_name = local.world_disk_name

  lifecycle {
    replace_triggered_by = [google_compute_instance.office]
  }
}

resource "terraform_data" "deploy_worldmods" {
  triggers_replace = [
    google_compute_instance.office.instance_id,
    google_compute_disk.office_world.id,
    local.worldmods_fingerprint,
  ]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command = "& '${path.module}/scripts/deploy-worldmods.ps1' -ProjectId '${var.project_id}' -Zone '${var.zone}' -InstanceName '${google_compute_instance.office.name}' -SshUser '${var.instance_ssh_user}' -WorldDiskDevice '/dev/disk/by-id/google-${local.world_disk_name}' -AccessModPath '${abspath("${path.module}/../../mod/trivium_access")}' -TriviumModPath '${abspath("${path.module}/../../mod/trivium")}'"
  }

  depends_on = [google_compute_instance.office, google_compute_attached_disk.office_world]
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