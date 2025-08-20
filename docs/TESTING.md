Absolutely—let’s turn this into a **top-tier, end-to-end testing guide** that anyone can clone and run.

Below is a complete Markdown doc you can drop into your repo as **`TESTING.md`** (or `docs/TESTING.md`). It’s self-contained, copy-pastable, and written so a new engineer can follow it start-to-finish without secrets committed to the repo.

---

# TESTING.md — End-to-End Validation Guide

This document shows how to:

* Verify AWS & GCP credentials
* Bootstrap secure **remote state** backends (S3+DynamoDB / GCS)
* Plan/apply/destroy **AWS** and **GCP** dev stacks with `make`
* Validate configuration + **policy as code (OPA)**
* Simulate **real-world mistakes** (console toggles, code changes) and see guardrails catch them
* Confirm **state locking & versioning**
* Clean up

> **Assumptions**
>
> * You didn’t commit any credentials. You’ll use **AWS CLI config** and **GCP gcloud**/Service Account locally.
> * Your repo has these paths: `envs/aws-dev`, `envs/gcp-dev`, `scripts/`, `policy/`, `modules/`.

---

## 0) Prereqs

* **Terraform** (v1.5+) — `terraform -version`
* **OPA** — `opa version`
* **AWS CLI** — `aws --version`
* **gcloud CLI** — `gcloud --version`
* Make sure your repo has the provided **`Makefile`** and scripts.

> If you haven’t yet, install:
>
> ```bash
> brew install hashicorp/tap/terraform
> brew install opa
> brew install --cask google-cloud-sdk
> ```

---

## 1) Clone and inspect

```bash
git clone https://github.com/<you>/secure-terraform-multicloud.git
cd secure-terraform-multicloud
make help
```

You should see a menu of `aws-*`, `gcp-*`, `validate`, `opa`, etc.

---

## 2) Verify AWS credentials (no secrets in repo)

Your AWS CLI should already be configured:

```bash
aws sts get-caller-identity
aws configure list
```

Expected output (example):

```json
{
  "UserId": "AIDA...55",
  "Account": "108271871935",
  "Arn": "arn:aws:iam::108271871935:user/oyelekan.admin"
}
```

> You can force the Makefile to fail if you’re on the wrong account:
>
> ```bash
> make aws-plan AWS_EXPECTED_ACCOUNT=108271871935
> ```

---

## 3) Verify GCP credentials (no secrets in repo)

Pick one auth method:

**A) Application Default Credentials (ADC)**

```bash
gcloud config set project terraform1718
gcloud auth application-default login
gcloud auth list
gcloud config list
```

**B) Service Account key file**

```bash
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/gcp-terraform-sa.json"
gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS"
gcloud auth list
gcloud config set project terraform1718
```

> Validate:
>
> ```bash
> gcloud services list --enabled | egrep 'compute|storage|iam'
> ```

> Fail fast if wrong project:
>
> ```bash
> make gcp-plan GCP_EXPECTED_PROJECT=terraform1718
> ```

---

## 4) Bootstrap **remote state** backends (one-time per account)

### 4.1 AWS: S3 bucket (versioned) + DynamoDB lock table

> Replace `tfstate-your-uniq-bucket` with a globally unique name.
> (Do this once per AWS account/region.)

```bash
aws s3api create-bucket --bucket tfstate-your-uniq-bucket --region us-east-1
aws s3api put-bucket-versioning --bucket tfstate-your-uniq-bucket --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name tf-state-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

Confirm:

```bash
aws s3api get-bucket-versioning --bucket tfstate-your-uniq-bucket
aws dynamodb describe-table --table-name tf-state-locks --query "Table.TableStatus"
```

Now set `envs/aws-dev/backend.tf` to use that bucket/table (already scaffolded in your repo).

### 4.2 GCP: GCS bucket (versioned)

> Replace `tfstate-your-uniq-gcs-bucket` with a unique name.

```bash
gsutil mb -c standard -l us-central1 gs://tfstate-your-uniq-gcs-bucket
gsutil versioning set on gs://tfstate-your-uniq-gcs-bucket
```

Confirm:

```bash
gsutil versioning get gs://tfstate-your-uniq-gcs-bucket
```

Ensure `envs/gcp-dev/backend.tf` points to that bucket (already scaffolded).

---

## 5) Initialize and plan — quick smoke

### 5.1 AWS

```bash
make aws-init
make aws-plan AWS_EXPECTED_ACCOUNT=108271871935
```

Expected: A plan with your VPC + private demo S3 bucket (no changes if already applied).

### 5.2 GCP

```bash
make gcp-init
make gcp-plan GCP_EXPECTED_PROJECT=terraform1718
```

Expected: A plan with a VPC network + subnetwork + private demo GCS bucket.

---

## 6) Apply **dev** environments

> **Heads up:** These create small billable resources (VPCs, buckets). Keep them in **dev** regions and destroy when done.

### 6.1 AWS apply

```bash
make aws-apply AWS_EXPECTED_ACCOUNT=108271871935
```

Verify in console/CLI:

* VPC exists:

  ```bash
  aws ec2 describe-vpcs --filters "Name=tag:Name,Values=vpc-main" \
    --query "Vpcs[].VpcId" --output table
  ```

* S3 **private** bucket exists (name will include a random hex):

  ```bash
  aws s3api list-buckets --query "Buckets[].Name"
  ```

* Public access block enabled:

  ```bash
  aws s3api get-public-access-block --bucket <your-demo-bucket>
  ```

  Expect all four flags `true`.

* **Encryption** enabled:

  ```bash
  aws s3api get-bucket-encryption --bucket <your-demo-bucket>
  ```

* **Versioning** enabled:

  ```bash
  aws s3api get-bucket-versioning --bucket <your-demo-bucket>
  ```

### 6.2 GCP apply

```bash
make gcp-apply GCP_EXPECTED_PROJECT=terraform1718
```

Verify:

* Network/subnet exist:

  ```bash
  gcloud compute networks list | grep vpc-main
  gcloud compute networks subnets list --regions=us-central1 | grep subnet-main
  ```
* GCS bucket exists, uniform access + versioning:

  ```bash
  gsutil ls -p terraform1718
  gsutil iam get gs://<your-demo-gcs-bucket> | jq .
  gsutil versioning get gs://<your-demo-gcs-bucket>
  ```

---

## 7) Validate config + policy (OPA)

### 7.1 Terraform validation across all envs

```bash
make validate
```

* Runs `terraform init -backend=false` + `terraform validate` in each `envs/*` (safe—doesn’t touch state).

### 7.2 OPA policy smoke test (no Terraform needed)

```bash
make opa
```

* Evaluates `policy/*.rego` using `policy/opa-input.example.json`.
* You should see the policy data printed. (No denies in the example.)

> **Advanced (using real plan JSON)**
> Generate a plan JSON and evaluate **deny** rules:
>
> ```bash
> cd envs/aws-dev
> terraform plan -out=tfplan
> terraform show -json tfplan > ../../policy/inputs/aws-dev.plan.json
> cd ../..
> opa eval -f pretty -i policy/inputs/aws-dev.plan.json -d policy 'data'
> ```
>
> Wire your Rego to read from `input.resource_changes` (Terraform plan schema) and surface violations via `data.<package>.deny`.

---

## 8) Real-world mistake simulations

### 8.1 **Console mistake** (AWS): try to make bucket public

* Go to the demo S3 bucket in console.
* Try enabling public ACLs or a public bucket policy.
* **Expected:** AWS blocks it because Terraform created an **S3 Public Access Block** with all four protections enabled.
* Run:

  ```bash
  aws s3api get-public-access-block --bucket <your-demo-bucket>
  ```

  Still enforced? ✅

> **Takeaway:** Even a root user can’t accidentally flip it public—controls are set at the bucket level.

### 8.2 **Console mistake** (GCP): add public member

* In console, add `allUsers` as `Viewer` to the demo bucket.
* That change **will succeed** (this is runtime drift).
* Now run:

  ```bash
  make gcp-plan
  ```

  **Expected:** The plan proposes to **remove** that public grant because your Terraform code does **not** include it.

> **Takeaway:** Terraform corrects drift on next apply; OPA prevents *introducing* the issue via code.

### 8.3 **Code mistake** (AWS): attempt to allow a public bucket

* In `envs/aws-dev/main.tf`, add a **second** test bucket with:

  ```hcl
  resource "aws_s3_bucket" "bad_public_example" {
    bucket = "BAD-public-${random_id.rand.hex}"
    acl    = "public-read" # <- explicitly public (bad)
  }
  ```
* Now:

  ```bash
  cd envs/aws-dev
  terraform plan -out=tfplan
  terraform show -json tfplan > ../../policy/inputs/aws-dev.plan.json
  cd ../..
  opa eval -f pretty -i policy/inputs/aws-dev.plan.json -d policy 'data'
  ```
* **Expected:** Your Rego (`bucket_no_public.rego`) should report a **deny**.
  In CI you’d **fail the build** on non-empty `deny`.

> **Takeaway:** Policy-as-code blocks insecure intent **before** cloud changes happen.

---

## 9) State locking & versioning checks

### 9.1 DynamoDB **state lock**

* In one terminal:

  ```bash
  make aws-apply
  ```
* Before it finishes, in a **second** terminal try:

  ```bash
  make aws-apply
  ```
* **Expected:** The second run hangs on **“Acquiring state lock”** (and releases when first finishes).
* Check the lock record:

  ```bash
  aws dynamodb scan --table-name tf-state-locks --output table
  ```

> **Takeaway:** Locking prevents two engineers from corrupting state by applying at the same time.

### 9.2 S3/GCS **versioning**

* Upload a dummy file, then overwrite it, then restore a previous version.

**AWS**

```bash
aws s3 cp ./README.md s3://<your-demo-bucket>/README.md
aws s3 cp ./TESTING.md s3://<your-demo-bucket>/README.md
aws s3api list-object-versions --bucket <your-demo-bucket> --prefix README.md
# Note the VersionId of the first upload, restore it:
aws s3api copy-object --bucket <your-demo-bucket> \
  --copy-source <your-demo-bucket>/README.md?versionId=<OLD_VERSION_ID> \
  --key README.md
```

**GCP**

```bash
gsutil cp ./README.md gs://<your-demo-gcs-bucket>/README.md
gsutil cp ./TESTING.md gs://<your-demo-gcs-bucket>/README.md
gsutil ls -a gs://<your-demo-gcs-bucket>/README.md
# To restore, copy the older generation back to the current key name:
gsutil cp gs://<your-demo-gcs-bucket>/README.md#<OLD_GENERATION> gs://<your-demo-gcs-bucket>/README.md
```

> **Takeaway:** Versioning is your time machine for accidental deletes/overwrites.

---

## 10) Cleanup

Destroy stacks (safe; the **backend buckets/tables** stay because they are not managed by these envs):

```bash
make aws-destroy AWS_EXPECTED_ACCOUNT=108271871935
make gcp-destroy GCP_EXPECTED_PROJECT=terraform1718
```

Optional: remove the **remote state backends** (do this **only** when done with the whole lab):

**AWS**

```bash
aws dynamodb delete-table --table-name tf-state-locks
aws s3 rm s3://tfstate-your-uniq-bucket --recursive
aws s3api delete-bucket --bucket tfstate-your-uniq-bucket
```

**GCP**

```bash
gsutil -m rm -r gs://tfstate-your-uniq-gcs-bucket
```

---

## 11) Troubleshooting

* **`Error acquiring the state lock`**
  An apply crashed mid-flight. Ensure no one is applying, then unlock by deleting the stuck item from `tf-state-locks` (as last resort).

* **`aws sts get-caller-identity` fails**
  Re-run `aws configure` or fix your profile/STS session.

* **`gcloud auth application-default login` error**
  Rerun and make sure you consent to `https://www.googleapis.com/auth/cloud-platform`.

* **`opa: command not found`**
  `brew install opa` and rerun `make opa`.

* **Public bucket change “succeeds” in console on GCP**
  That’s expected—runtime drift. Terraform plan/apply removes it; OPA blocks adding it via code.

---

## 12) What you proved

* **IaC repeatability**: One repo brings up AWS+GCP infra in a standard way.
* **Secure state**: S3+KMS (SSE), versioning, and **DynamoDB locking**; GCS with versioning.
* **Guardrails**: S3 public access block prevents console mistakes; OPA blocks insecure intent at **plan time**.
* **Multi-cloud modules**: Same mental model (VPC/VNet) across providers.

---

### One-command smoke run (copy/paste)

```bash
# AWS
make aws-init
make aws-plan AWS_EXPECTED_ACCOUNT=108271871935
make aws-apply AWS_EXPECTED_ACCOUNT=108271871935

# GCP
make gcp-init
make gcp-plan GCP_EXPECTED_PROJECT=terraform1718
make gcp-apply GCP_EXPECTED_PROJECT=terraform1718

# Validation / Policy
make validate
make opa

# Destroy when done
make aws-destroy AWS_EXPECTED_ACCOUNT=108271871935
make gcp-destroy GCP_EXPECTED_PROJECT=terraform1718
```

---

If you want, I can also add a **CI job example** (GitHub Actions) that runs `make validate`, builds a plan JSON per env, runs **OPA `deny`**, and fails the PR on violations.
