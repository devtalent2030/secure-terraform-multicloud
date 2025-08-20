#############################################
# envs/aws-dev/main.tf
#
# Purpose:
#   - The actual infrastructure definition for AWS dev.
#   - Wires together reusable modules + any environment-only resources.
#
# Connection:
#   - Calls into ../../modules/aws_network for VPC.
#   - Creates demo S3 bucket with random suffix.
#   - Outputs VPC ID so other stacks/tools can consume it.
#############################################

# Reusable AWS VPC module
module "network" {
  source    = "../../modules/aws_network"
  vpc_cidr  = var.vpc_cidr

  tags = {
    Project = var.project_tag
    Env     = "dev"
  }
}

# Example: secure, private S3 bucket (not public)
resource "aws_s3_bucket" "state_demo" {
  bucket = "demo-${var.project_tag}-${random_id.rand.hex}"
  tags   = {
    Project = var.project_tag
    Env     = "dev"
  }
}

# Random hex ensures bucket name is globally unique
resource "random_id" "rand" {
  byte_length = 4
}

# Useful output for downstream use (peering, app modules, etc.)
output "vpc_id" {
  value = module.network.vpc_id
}
