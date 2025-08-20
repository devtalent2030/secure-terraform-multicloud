#############################################
# envs/gcp-dev/variables.tf
#
# Purpose:
#   - Declare inputs for this root module.
#   - Keep defaults sane, but allow override via .tfvars/CLI.
#############################################

variable "project_id" {
  type        = string
  description = "GCP project ID to deploy into (e.g., terraform1718)"
}

variable "gcp_region" {
  type        = string
  description = "Primary region for regional resources"
  default     = "us-central1"
}

variable "network_cidr" {
  type        = string
  description = "CIDR for the primary subnetwork"
  default     = "10.20.0.0/16"
}

variable "labels" {
  type        = map(string)
  description = "Common labels attached to label-capable resources"
  default     = {
    managed_by = "terraform"
    env        = "dev"
    project    = "secure-terraform"
  }
}
