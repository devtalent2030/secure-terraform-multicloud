#############################################
# modules/gcp_network/main.tf
#
# Minimal, safe-by-default VPC + one subnetwork.
# NOTE: google_compute_subnetwork does NOT support `labels`.
# If you want searchable metadata, encode a short string into `description`.
#############################################

locals {
  # Stable names; change only via versioned releases.
  network_name = "vpc-main"
  subnet_name  = "subnet-main"

  # Caller-provided metadata we might mirror into descriptions.
  # (Not all GCP resources accept labels; subnetworks do not.)
  base_labels = merge(
    {
      managed_by = "terraform"
      module     = "gcp_network"
    },
    var.labels
  )

  # Optional: flatten labels to a short "k=v,k=v" string for descriptions/logging.
  labels_kv = join(
    ",",
    [for k, v in local.base_labels : "${k}=${v}"]
  )
}

# Global VPC (no auto subnets so CIDR planning stays explicit).
resource "google_compute_network" "vpc" {
  name                    = local.network_name
  project                 = var.project_id
  auto_create_subnetworks = false
  # google_compute_network also doesn't support `labels`; keep it clean.
  # You can add a description if you want:
  # description = "managed_by=terraform,module=gcp_network"
}

# Regional subnetwork with explicit CIDR.
# Subnetworks DO NOT support `labels`, so we use `description` if we want metadata.
resource "google_compute_subnetwork" "subnet" {
  name          = local.subnet_name
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.network_cidr

  # Sensible default: reach Google APIs without a public IP.
  private_ip_google_access = true

  # Flow logs / secondary ranges / NAT can be added when needed.

  # (Optional) Put provenance metadata here; keep brief to avoid API length limits.
  description = "managed_by=terraform,module=gcp_network${length(local.labels_kv) > 0 ? "," : ""}${local.labels_kv}"
}
