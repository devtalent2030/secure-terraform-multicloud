#############################################
# modules/aws_network/outputs.tf
#
# The module's OUTPUTS—values callers can depend on.
# These outputs become the "return values" at module.<name>.<output>.
#############################################

# Consumers often need the VPC ID to attach subnets, gateways, security groups, etc.
output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.this.id
}

# Example additional outputs you can expose later as the module grows:
# output "vpc_arn"    { value = aws_vpc.this.arn }
# output "vpc_cidr"   { value = aws_vpc.this.cidr_block }
# output "vpc_tags"   { value = aws_vpc.this.tags }
