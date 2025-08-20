#############################################
# modules/aws_network/variables.tf
#
# This file declares the module's INPUTS.
# Treat this like the module's "public API".
# Callers (envs/*) must/should set these.
#############################################

# Required: the address space for the VPC.
# We intentionally do NOT validate CIDR shape here (keep the module flexible).
# If you want stricter contracts, add a validation block (e.g., cidrsubnet() checks).
variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC, e.g., 10.10.0.0/16"
}

# Optional: free-form key/value metadata applied to resources.
# Tags are a must-have for ownership, cost, and security scoping (org policy can require these).
variable "tags" {
  type        = map(string)
  description = "Common tags to apply to all AWS network resources"
  default     = {}
}
