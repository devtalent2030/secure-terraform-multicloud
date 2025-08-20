#############################################
# envs/gcp-dev/backend.tf
#
# Purpose:
#   - Store Terraform state in a GCS bucket (shared + versioned).
#   - One state per env (clean blast radius, easy rollbacks).
#
# Notes:
#   - GCS has object versioning but no native state locking like DynamoDB.
#     That's OK for solo/dev. For teams, use Terraform Cloud or add a lock
#     pattern (e.g., run applies through a single CI job).
#############################################

terraform {
  backend "gcs" {
    bucket = "tfstate-your-uniq-gcs-bucket" # <- create once, globally unique in your project/org
    prefix = "gcp/dev"                       # <- folder-ish prefix inside the bucket
  }
}
