# Secure Multi-Cloud Terraform (AWS + GCP) — Full Guide

> **Purpose:** A production-style starter showing how to provision AWS & GCP with Terraform using **remote state**, **locking**, **secure defaults**, **drift detection**, and **policy-as-code (OPA)** — wrapped in a simple Makefile workflow.

---

## TL;DR

```bash
# From repo root
make aws-init
make aws-plan  AWS_EXPECTED_ACCOUNT=<ACCOUNT_ID>
make aws-apply AWS_EXPECTED_ACCOUNT=<ACCOUNT_ID>

make gcp-init
make gcp-plan  GCP_EXPECTED_PROJECT=<PROJECT_ID>
make gcp-apply GCP_EXPECTED_PROJECT=<PROJECT_ID>
```

* **Remote state** lives in S3 (+ DynamoDB lock) and/or GCS with **versioning & encryption**.
* **Buckets** are secure-by-default (S3 PAB + encryption + versioning; GCS UBLA + versioning).
* **Drift**: console changes are detected by `terraform plan` and reverted by `apply`.
* **Policy**: OPA can deny insecure intent at plan time.

---

## Architecture (high level)

```
Terraform CLI / CI
       │
       ├──► Remote State (S3 + DynamoDB)  [AWS]
       │                (GCS)             [GCP]
       │
       ├──► AWS: VPC + secure S3 bucket (private, encrypted, versioned)
       │
       └──► GCP: VPC + secure GCS bucket (UBLA, versioned)

Policy-as-code (OPA) can run against `terraform show -json` plans in CI.
Makefile provides reproducible one-liners for all workflows.
```

---

## Repo Layout

```
envs/
  aws-dev/
    backend.tf      # points to S3 + DynamoDB
    main.tf         # VPC + secure demo S3
    dev.tfvars
  gcp-dev/
    backend.tf      # points to GCS
    main.tf         # VPC + secure demo GCS
    dev.tfvars
modules/
  aws_network/      # reusable VPC for AWS
  gcp_network/      # reusable VPC for GCP
policy/
  *.rego            # OPA policies
  inputs/           # plan.jsons for eval
scripts/
Makefile            # standardized workflow
```

---

## Prerequisites

* Terraform **v1.5+**
* AWS CLI configured (`aws configure`) with access to your account
* Google Cloud SDK (`gcloud`) and **ADC** (`gcloud auth application-default login`)
* OPA (`opa version`)
* GNU Make

Quick checks:

```bash
terraform -version
aws --version
gcloud --version
opa version
```

---

## Backends (Remote State) — One-Time Setup

> A **backend** is just cloud storage that Terraform uses for `terraform.tfstate`, plus a **lock** to prevent concurrent writes.

### AWS backend (S3 + DynamoDB)

Create a unique, versioned bucket and a lock table:

```bash
export TFSTATE_AWS_BUCKET="tfstate-$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-')"
aws s3api create-bucket --bucket "$TFSTATE_AWS_BUCKET" --region us-east-1
aws s3api put-bucket-versioning --bucket "$TFSTATE_AWS_BUCKET" --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name tf-state-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

aws dynamodb wait table-exists --table-name tf-state-locks
```

Point `envs/aws-dev/backend.tf` at that bucket & table, then:

```bash
cd envs/aws-dev
terraform init -reconfigure
cd ../..
```

### GCP backend (GCS)

```bash
export TFSTATE_GCS_BUCKET="tfstate-$(uuidgen | tr '[:upper:]' '[:lower:]' | sed 's/-//g' | cut -c1-16)"
gsutil mb -c standard -l us-central1 "gs://${TFSTATE_GCS_BUCKET}"
gsutil versioning set on "gs://${TFSTATE_GCS_BUCKET}"
```

Update `envs/gcp-dev/backend.tf` to use that bucket, then:

```bash
cd envs/gcp-dev
terraform init -reconfigure
cd ../..
```

---

## Makefile Workflow

Run from **repo root**:

```
make aws-init     # terraform init in envs/aws-dev
make aws-plan     # plan with var-file (defaults to dev.tfvars)
make aws-apply    # apply (auto-approve)
make aws-destroy  # destroy

make gcp-init
make gcp-plan
make gcp-apply
make gcp-destroy

make validate     # terraform validate across envs (backend=false)
make opa          # evaluate OPA policies on plan JSONs
make fmt          # terraform fmt -recursive
make clean-local  # remove local .terraform/ .tfstate (safe)
```

Helpful flags:

```
make aws-plan  AWS_EXPECTED_ACCOUNT=<ACCOUNT_ID>
make gcp-plan  GCP_EXPECTED_PROJECT=<PROJECT_ID>
```

These fail fast if you’re pointed at the wrong account/project.

---

## Provisioning

### AWS Dev

```bash
make aws-plan  AWS_EXPECTED_ACCOUNT=<ACCOUNT_ID>
make aws-apply AWS_EXPECTED_ACCOUNT=<ACCOUNT_ID>
```

**Verifications:**

```bash
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=vpc-main" \
  --query "Vpcs[].VpcId" --output table

# Public Access Block must be all true
aws s3api get-public-access-block --bucket <DEMO_S3_BUCKET>

# Encryption + Versioning
aws s3api get-bucket-encryption --bucket <DEMO_S3_BUCKET>
aws s3api get-bucket-versioning --bucket <DEMO_S3_BUCKET>
```

> Recommended to manage posture explicitly in code:
>
> ```hcl
> resource "aws_s3_bucket_public_access_block" "state_demo_pab" {
>   bucket                  = aws_s3_bucket.state_demo.id
>   block_public_acls       = true
>   ignore_public_acls      = true
>   block_public_policy     = true
>   restrict_public_buckets = true
> }
>
> resource "aws_s3_bucket_server_side_encryption_configuration" "state_demo_sse" {
>   bucket = aws_s3_bucket.state_demo.id
>   rule {
>     apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
>     bucket_key_enabled = false
>   }
> }
> ```

### GCP Dev

```bash
make gcp-plan  GCP_EXPECTED_PROJECT=<PROJECT_ID>
make gcp-apply GCP_EXPECTED_PROJECT=<PROJECT_ID>
```

**Verifications:**

```bash
gcloud compute networks list | grep vpc-main || true
gcloud compute networks subnets list --regions=us-central1 | grep subnet-main || true

# UBLA + Versioning
gsutil ls -L -b gs://<DEMO_GCS_BUCKET> | egrep -i 'Uniform bucket-level access|Versioning'
gsutil iam get gs://<DEMO_GCS_BUCKET> | jq .
```

---

## Drift Detection & Self-Heal

**AWS example** — suspend versioning in console; then:

```bash
make aws-plan  AWS_EXPECTED_ACCOUNT=<ACCOUNT_ID>   # should propose re-enabling
make aws-apply AWS_EXPECTED_ACCOUNT=<ACCOUNT_ID>   # heals it
aws s3api get-bucket-versioning --bucket <DEMO_S3_BUCKET>
```

**GCP example** — turn off UBLA or versioning in console; then:

```bash
make gcp-plan  GCP_EXPECTED_PROJECT=<PROJECT_ID>   # proposes fix
make gcp-apply GCP_EXPECTED_PROJECT=<PROJECT_ID>   # heals it
```

> Guardrails vs drift: S3 Public Access Block **prevents** bad console changes from landing; versioning/UBLA changes **do** land and are then detected & fixed by Terraform.

---

## Policy-as-Code (OPA)

Block insecure *intent* **before** apply.

**Sample Rego** (`policy/s3_no_public.rego`):

```rego
package s3.no_public

deny[msg] {
  some rc in input.resource_changes
  rc.type == "aws_s3_bucket"
  rc.change.after.acl == "public-read"
  msg := sprintf("Public S3 bucket not allowed: %v", [rc.name])
}
```

**Evaluate against plan JSON:**

```bash
cd envs/aws-dev
terraform plan -out=tfplan
terraform show -json tfplan > ../../policy/inputs/aws-dev.plan.json
cd ../..

opa eval -f pretty -i policy/inputs/aws-dev.plan.json -d policy 'data'
```

In CI, fail the job if `deny` is non-empty.

---

## State Locking & Visibility

**Locking test (AWS/DynamoDB):**

* Start `make aws-apply` in one terminal, then start it again in another.
* The second should wait on “Acquiring state lock…”.

**Inspect state (safe):**

```bash
cd envs/aws-dev && terraform state pull | jq . | head -n 20 && cd ../..
cd envs/gcp-dev && terraform state pull | jq . | head -n 20 && cd ../..
```

**List state object versions:**

```bash
# AWS S3 (replace bucket/key)
aws s3api list-object-versions \
  --bucket <AWS_STATE_BUCKET> \
  --prefix aws-dev/terraform.tfstate \
  --query 'Versions[].{Id:VersionId,IsLatest:IsLatest,LastModified:LastModified}'

# GCP GCS (replace)
gsutil ls -a gs://<GCS_STATE_BUCKET>/gcp-dev/state/default.tfstate
```

---

## Collaboration Model (typical)

* **Git PRs** are the interface; CI runs `fmt`, `validate`, `plan`, **OPA**.
* **Apply** is performed by a **service account/role** (not humans).
* **State**: shared, versioned, encrypted; reads in CI, writes by CI role.
* Separate state/object prefixes per env (e.g., `aws-dev/…`, `gcp-dev/…`).

---

## Production Hardening (next steps)

* Use **SSE-KMS** for S3 with CMKs + tight key policy; similar for GCS CMEK.
* S3 bucket policy: deny non-TLS (`aws:SecureTransport = false`), deny unencrypted PUTs, scope prefixes.
* GCS: add retention/soft-delete windows for stronger recovery.
* Per-env isolation (separate AWS accounts / GCP projects, separate state buckets).
* End-to-end CI with manual approval gates for prod.

---

## Troubleshooting

* **Bucket keeps being replaced in plan**
  A name-driving var (e.g., `project_tag`) changed. S3 bucket names are immutable; keep naming inputs stable.

* **GCS backend 403 (wrong identity)**
  Terraform uses **ADC**, which can differ from `gcloud auth list`. Reset:

  ```bash
  gcloud auth application-default revoke -q || true
  gcloud auth application-default login
  gsutil iam ch user:<you>@gmail.com:roles/storage.objectAdmin gs://<GCS_STATE_BUCKET>
  ```

* **S3 delete fails (versioned bucket)**
  Empty versions first, then delete:

  ```bash
  aws s3 rm s3://<AWS_STATE_BUCKET> --recursive
  aws s3api delete-bucket --bucket <AWS_STATE_BUCKET>
  ```

* **PAB drift not detected**
  Ensure `aws_s3_bucket_public_access_block` is managed in Terraform.

---

## Cleanup

```bash
# Destroy stacks
make aws-destroy AWS_EXPECTED_ACCOUNT=<ACCOUNT_ID>
make gcp-destroy GCP_EXPECTED_PROJECT=<PROJECT_ID>

# Optional: delete backends (after stacks are gone)
aws s3 rm s3://<AWS_STATE_BUCKET> --recursive && aws s3api delete-bucket --bucket <AWS_STATE_BUCKET>
aws dynamodb delete-table --table-name tf-state-locks
gsutil -m rm -r gs://<GCS_STATE_BUCKET>
```

---

## FAQ

**Q: Can my team of 10 share this state safely?**
Yes — that’s the point of backends: **shared, versioned, encrypted state** with **locking**. Usually only CI has write access; humans plan via CI.

**Q: How do we audit who changed what?**
Use S3/GCS audit logs (and CloudTrail for S3 data events). State object versions + CI logs provide full traceability.

**Q: Why manage security posture in Terraform if cloud has guardrails?**
So your desired posture is **codified**, **detectable**, and **auto-healable**. Guardrails prevent some mistakes; IaC ensures consistency.

---

**License:** MIT (or your choice)
**Maintainers:** *Add names / emails here*
