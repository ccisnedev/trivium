locals {
  effective_state_bucket_name     = coalesce(var.state_bucket_name, "${var.project_id}-tfstate")
  effective_artifacts_bucket_name = coalesce(var.artifacts_bucket_name, "${var.project_id}-artifacts")
  required_services = toset([
    "compute.googleapis.com",
    "dns.googleapis.com",
    "storage.googleapis.com",
  ])
}

resource "google_project" "this" {
  project_id          = var.project_id
  name                = var.project_name
  billing_account     = var.billing_account
  auto_create_network = true
}

resource "google_project_service" "required" {
  for_each = local.required_services

  project            = google_project.this.project_id
  service            = each.key
  disable_on_destroy = false

  depends_on = [google_project.this]
}

resource "google_storage_bucket" "terraform_state" {
  name                        = local.effective_state_bucket_name
  project                     = google_project.this.project_id
  location                    = var.region
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  depends_on = [google_project_service.required["storage.googleapis.com"]]
}

resource "google_storage_bucket" "artifacts" {
  name                        = local.effective_artifacts_bucket_name
  project                     = google_project.this.project_id
  location                    = var.region
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  depends_on = [google_project_service.required["storage.googleapis.com"]]
}