#############################################
# envs/gcp-dev/providers.tf
#
# Purpose:
#   - Pin Terraform & Google provider versions for deterministic runs.
#   - Configure the Google provider (project + region) via variables.
#
# Auth:
#   - Uses ADC (Application Default Credentials) by default:
#       gcloud auth application-default login
#     OR:
#   - Set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON key.
#############################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.41"  # pin so provider changes don't silently break you
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.gcp_region
  # Auth resolved via:
  #  - ADC (preferred for local dev), or
  #  - GOOGLE_APPLICATION_CREDENTIALS pointing to a key file.
}
