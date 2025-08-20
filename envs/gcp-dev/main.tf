#############################################
# envs/gcp-dev/main.tf
#
# Purpose:
#   - Compose your dev VPC (via module) + a demo secure bucket.
#   - Expose outputs other stacks can consume (e.g., VPC name).
#
# Connections:
#   - Calls ../../modules/gcp_network (reusable VPC).
#   - Creates one private GCS bucket with versioning.
#   - Outputs the VPC name for downstream use/visibility.
#############################################

# Reusable VPC module (keeps network logic DRY across envs)
module "network" {
  source       = "../../modules/gcp_network"
  project_id   = var.project_id
  region       = var.gcp_region
  network_cidr = var.network_cidr
  labels       = var.labels
}

# Add a tiny random suffix so bucket names are globally unique
resource "random_id" "rand" {
  byte_length = 4
}

# Secure-by-default GCS bucket:
# - uniform_bucket_level_access: true => IAM-only control (no object ACL drift)
# - versioning: on => rollback & forensics
# - force_destroy: true (dev convenience) => delete even if objects exist
resource "google_storage_bucket" "state_demo" {
  name          = "demo-${var.project_id}-${random_id.rand.hex}"
  project       = var.project_id
  location      = var.gcp_region
  force_destroy = true

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  labels = var.labels
}

# Output something useful so other stacks / humans can reference it
output "vpc_name" {
  value       = module.network.network_name
  description = "Name of the VPC created by modules/gcp_network"
}
