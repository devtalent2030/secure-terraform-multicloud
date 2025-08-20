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
    bucket         = "tfstate-your-uniq-bucket"  # << Create once, globally unique
    key            = "aws/dev/terraform.tfstate" # << Logical path inside bucket
    region         = "us-east-1"                 # << Match AWS_REGION
    dynamodb_table = "tf-state-locks"            # << Create once; prevents concurrent ops
    encrypt        = true                        # << Force SSE encryption
  }
}
