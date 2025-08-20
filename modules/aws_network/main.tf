#############################################
# modules/aws_network/main.tf
#
# This is the module IMPLEMENTATION.
# It creates a minimal VPC and bakes in sane defaults.
# Keep it focused; compose subnets/IGWs/NAT in this module later
# or via sibling modules if you prefer smaller pieces.
#############################################

# Locals centralize derived values and defaults in one place.
# This pattern makes refactors safer and reduces duplication.
locals {
  # Merge caller-provided tags with enforced/common tags.
  # Caller can overwrite keys if needed (merge order: left wins on conflict).
  # If you want to enforce org tags, put them on the RIGHT of merge() instead.
  base_tags = merge(
    {
      ManagedBy = "terraform"
      Module    = "aws_network"
    },
    var.tags
  )
}

# Core network primitive: the VPC.
# - enable_dns_hostnames: true is a common requirement (EKS, ECS, RDS integration, private hosted zones).
# - We do not create subnets/IGW/NAT here yet—keep module minimal and composable.
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tagging at creation time ensures cost/ownership discoverability and policy compliance.
  tags = merge(local.base_tags, {
    Name = "vpc-main"
  })
}

# (Optional) Add future building blocks here when you’re ready:
# - aws_internet_gateway.this
# - aws_subnet.public/private
# - aws_route_table + associations
# - aws_nat_gateway + eip, etc.
#
# Keep module boundaries crisp: either this module becomes "full network"
# (VPC + subnets + IGW + NAT + routes) or you create smaller modules and
# compose them in envs. Both are valid—pick a style and stick to it org-wide.
