variable "project_id" {
  description = "Unique GCP project ID for the Trivium office environment."
  type        = string
}

variable "project_name" {
  description = "Display name for the GCP project."
  type        = string
  default     = "cacsi-virtual-office"
}

variable "billing_account" {
  description = "Billing account ID to attach to the new GCP project."
  type        = string
}

variable "region" {
  description = "Default region used by bootstrap resources."
  type        = string
  default     = "us-central1"
}

variable "state_bucket_name" {
  description = "Optional override for the Terraform remote state bucket name."
  type        = string
  default     = null
  nullable    = true
}

variable "artifacts_bucket_name" {
  description = "Optional override for the private GCS bucket used to store Luanti release artifacts."
  type        = string
  default     = null
  nullable    = true
}