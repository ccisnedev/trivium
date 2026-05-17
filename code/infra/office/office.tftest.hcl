mock_provider "google" {}

variables {
  project_id  = "cacsi-virtual-office"
  admin_cidrs = ["203.0.113.10/32"]
}

run "office_server_defaults" {
  command = plan

  assert {
    condition     = google_compute_instance.office.machine_type == "e2-small"
    error_message = "Office VM must default to e2-small."
  }

  assert {
    condition     = google_compute_instance.office.boot_disk[0].initialize_params[0].size == 20
    error_message = "Office VM must allocate a 20GB boot disk."
  }

  assert {
    condition     = anytrue([for rule in google_compute_firewall.luanti.allow : rule.protocol == "udp" && contains(rule.ports, "30000")])
    error_message = "Luanti firewall rule must expose UDP 30000."
  }

  assert {
    condition     = contains(tolist(google_compute_firewall.ssh.source_ranges), "203.0.113.10/32")
    error_message = "SSH firewall rule must restrict access to the configured admin CIDR."
  }

  assert {
    condition     = strcontains(google_compute_instance.office.metadata_startup_script, "VoxeLibre")
    error_message = "Startup script must install VoxeLibre on the VM."
  }

  assert {
    condition     = output.hostname == "office.cacsi.dev"
    error_message = "Office module must expose the connection hostname."
  }

  assert {
    condition     = output.luanti_port == 30000
    error_message = "Office module must expose the Luanti port."
  }
}

run "dns_is_optional" {
  command = plan

  variables {
    dns_managed_zone = null
  }

  assert {
    condition     = output.dns_mode == "manual"
    error_message = "Office module must support a manual DNS workflow when the zone is not managed in GCP."
  }
}