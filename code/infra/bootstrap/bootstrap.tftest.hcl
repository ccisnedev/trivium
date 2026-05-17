mock_provider "google" {}

variables {
  project_id      = "cacsi-virtual-office"
  project_name    = "cacsi-virtual-office"
  billing_account = "000000-000000-000000"
  region          = "us-central1"
}

run "bootstrap_contract" {
  command = plan

  assert {
    condition     = google_project.this.project_id == "cacsi-virtual-office"
    error_message = "Bootstrap must create the requested GCP project."
  }

  assert {
    condition     = output.project_id == "cacsi-virtual-office"
    error_message = "Bootstrap must expose the created project ID."
  }

  assert {
    condition     = contains(tolist(output.required_services), "compute.googleapis.com")
    error_message = "Bootstrap must enable Compute Engine API."
  }

  assert {
    condition     = contains(tolist(output.required_services), "dns.googleapis.com")
    error_message = "Bootstrap must enable Cloud DNS API."
  }

  assert {
    condition     = contains(tolist(output.required_services), "storage.googleapis.com")
    error_message = "Bootstrap must enable Cloud Storage API for Terraform state."
  }

  assert {
    condition     = output.state_bucket_name == "cacsi-virtual-office-tfstate"
    error_message = "Bootstrap must derive a predictable Terraform state bucket name by default."
  }
}