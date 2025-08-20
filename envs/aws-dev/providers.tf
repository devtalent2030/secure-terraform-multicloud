#############################################
# envs/aws-dev/providers.tf
#
# Purpose:
#   - Declare AWS provider (and its version constraint).
#   - Pin Terraform and provider versions for reproducibility.
#
# Connection:
#   - Provider block reads in variables from dev.tfvars.
#   - All resources/modules in this env inherit this provider.
#############################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.9"   # << Pin to prevent breaking changes
    }
  }
}

provider "aws" {
  region = var.aws_region
}
