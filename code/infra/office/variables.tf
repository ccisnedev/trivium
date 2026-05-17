variable "project_id" {
  description = "GCP project ID hosting the office world."
  type        = string
}

variable "region" {
  description = "Region for regional resources such as the static IP."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone hosting the office VM."
  type        = string
  default     = "us-central1-a"
}

variable "machine_type" {
  description = "Compute Engine machine type for the office server."
  type        = string
  default     = "e2-small"
}

variable "instance_name" {
  description = "Name of the office world VM."
  type        = string
  default     = "office-server"
}

variable "hostname" {
  description = "Public hostname used by local clients to connect."
  type        = string
  default     = "office.cacsi.dev"
}

variable "network" {
  description = "VPC network name for the office VM."
  type        = string
  default     = "default"
}

variable "subnetwork" {
  description = "Optional VPC subnetwork self link or name."
  type        = string
  default     = null
  nullable    = true
}

variable "admin_cidrs" {
  description = "CIDR blocks allowed to SSH into the office VM."
  type        = list(string)
}

variable "luanti_port" {
  description = "UDP port exposed by the Luanti server."
  type        = number
  default     = 30000
}

variable "disk_size_gb" {
  description = "Boot disk size in GB."
  type        = number
  default     = 20
}

variable "dns_managed_zone" {
  description = "Optional Cloud DNS managed zone name for automatically creating the office record."
  type        = string
  default     = null
  nullable    = true
}