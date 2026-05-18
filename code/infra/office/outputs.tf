output "hostname" {
  description = "Hostname that local clients should use to reach the office server."
  value       = var.hostname
}

output "instance_name" {
  description = "Compute Engine instance name for the office server."
  value       = google_compute_instance.office.name
}

output "machine_type" {
  description = "Machine type currently selected for the office server."
  value       = google_compute_instance.office.machine_type
}

output "luanti_port" {
  description = "UDP port exposed by the Luanti server."
  value       = var.luanti_port
}

output "static_ip" {
  description = "Reserved public IP address for the office server."
  value       = google_compute_address.office.address
}

output "dns_mode" {
  description = "Whether the DNS record is managed by Cloud DNS or must be updated manually."
  value       = var.dns_managed_zone == null ? "manual" : "managed"
}

output "vm_service_account_email" {
  description = "Dedicated service account email used by the office VM."
  value       = google_service_account.office_vm.email
}