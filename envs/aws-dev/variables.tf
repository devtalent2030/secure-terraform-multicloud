#############################################
# envs/aws-dev/variables.tf
#
# Purpose:
#   - Declare inputs this environment needs.
#   - Provide defaults where sensible; leave others required.
#
# Connection:
#   - Values come from dev.tfvars (or CLI overrides).
#   - Fed downstream into modules/resources in main.tf.
#############################################

variable "aws_region" {
  type        = string
  description = "AWS region for this environment"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.10.0.0/16"
}

variable "project_tag" {
  type        = string
  description = "Common tag for resources"
  default     = "secure-terraform"
}
