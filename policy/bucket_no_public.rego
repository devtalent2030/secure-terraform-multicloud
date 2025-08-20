# ------------------------------------------------------------------------------
# Rego policy for Open Policy Agent (OPA).
# Purpose:
#   Deny creation of publicly accessible buckets in AWS (S3) and GCP (GCS).
#
# How it connects:
#   - The `opa-eval.sh` script (in /scripts) loads this file.
#   - Terraform plan JSON is converted into structured input.
#   - This policy inspects that input for violations.
#
# What it teaches you:
#   - "Policy-as-code": you don't just configure infra, you enforce rules
#     as executable code.
#   - Example of "shift-left security" → catch issues BEFORE apply.
#
# Senior insight:
#   - Rego is declarative: you write what "should not happen."
#   - This sample checks only buckets, but you could extend to IAM,
#     networking, tagging, encryption, etc.
# ------------------------------------------------------------------------------

package policy

# ---- AWS check: deny if S3 bucket ACL is public
deny[msg] {
  some b
  bucket := input.buckets[b]
  bucket.cloud == "aws"
  lower(bucket.acl) == "public-read" or lower(bucket.acl) == "public-read-write"
  msg := sprintf("AWS S3 bucket %q must not be public (acl=%q)", [bucket.name, bucket.acl])
}

# ---- GCP check: deny if GCS bucket members include public principals
deny[msg] {
  some b
  bucket := input.buckets[b]
  bucket.cloud == "gcp"
  some m
  bucket.members[m] == "allUsers" or bucket.members[m] == "allAuthenticatedUsers"
  msg := sprintf("GCP GCS bucket %q must not grant public access (%q)", [bucket.name, bucket.members[m]])
}
