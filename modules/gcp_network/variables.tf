#############################################
# modules/gcp_network/variables.tf
#
# Module INPUTS (the public API callers rely on).
# Keep this surface clear and documented; it's what you version over time.
#############################################

# Who owns the resources: all network objects require a project.
variable "project_id" {
  type        = string
  description = "GCP project ID that owns this VPC and subnetwork"
}

# Address space for the first subnetwork (VPC itself has no CIDR).
# We keep this explicit to make address planning deliberate per env.
variable "network_cidr" {
  type        = string
  description = "CIDR for the primary subnetwork, e.g., 10.20.0.0/16"
}

# Region for the subnetwork. VPCs are global, but subnets are regional in GCP.
# We pass it in to avoid hidden coupling to any provider default.
variable "region" {
  type        = string
  description = "Region in which to create the subnetwork (e.g., us-central1)"
}

# Optional labels (GCP's equivalent to tags). Useful for cost, ownership, queries.
variable "labels" {
  type        = map(string)
  description = "Key/value labels applied to network resources where supported"
  default     = {}
}
