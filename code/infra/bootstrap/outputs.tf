output "project_id" {
  description = "Created GCP project ID."
  value       = google_project.this.project_id
}

output "project_name" {
  description = "Display name of the created GCP project."
  value       = google_project.this.name
}

output "required_services" {
  description = "APIs enabled by the bootstrap stack."
  value       = sort(tolist(local.required_services))
}

output "state_bucket_name" {
  description = "GCS bucket name to use as Terraform remote state backend."
  value       = google_storage_bucket.terraform_state.name
}

output "artifacts_bucket_name" {
  description = "Private GCS bucket name used to store versioned Luanti release artifacts."
  value       = google_storage_bucket.artifacts.name
}