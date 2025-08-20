#############################################
# envs/aws-dev/backend.tf
#
# Purpose:
#   - Configure *remote state* storage for this environment.
#   - Ensures team members all share one authoritative tfstate.
#   - Adds DynamoDB locking to prevent race conditions.
#
# Connection:
#   - Used by Terraform itself, not by providers.
#   - Must be bootstrapped once per account (bucket + DynamoDB).
#############################################

terraform {
  backend "s3" {
    bucket         = "tfstate-ca2865d1cd37461887cb32f8d1e6ffbe"
    key            = "aws-dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-state-locks"
    encrypt        = true
  }
}
