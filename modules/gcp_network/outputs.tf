#############################################
# modules/gcp_network/outputs.tf
#
# Module OUTPUTS: what callers can depend on.
# Keep names stable; changing output names is a breaking API change for callers.
#############################################

# Commonly needed when creating routers, firewalls, or peering later.
output "network_name" {
  description = "Name of the created VPC network"
  value       = google_compute_network.vpc.name
}

output "network_self_link" {
  description = "Self-link URI of the VPC (useful for cross-resource references)"
  value       = google_compute_network.vpc.self_link
}

output "subnet_name" {
  description = "Name of the created subnetwork"
  value       = google_compute_subnetwork.subnet.name
}

output "subnet_self_link" {
  description = "Self-link URI of the subnetwork"
  value       = google_compute_subnetwork.subnet.self_link
}

output "subnet_region" {
  description = "Region of the subnetwork (echoes input for convenience)"
  value       = google_compute_subnetwork.subnet.region
}

output "subnet_cidr" {
  description = "CIDR of the subnetwork (echoes input for convenience)"
  value       = google_compute_subnetwork.subnet.ip_cidr_range
}
