# ------------------------------------------------------------------------------
# Makefile
# Purpose: One-command entry point for every common action (init/plan/apply/destroy)
# Key features:
#   - Preflight guards (AWS/GCP) prevent running against the wrong account/project.
#   - Banner prints target env + var file to avoid prod mistakes.
#   - Consistent flags: -var-file, -auto-approve (where safe).
#   - Optional EXPECTED_ACCOUNT / EXPECTED_PROJECT to “lock” the session.
#   - Colorized, self-documented via `make help`.
# Connections:
#   - Calls scripts/tf-validate.sh and scripts/opa-eval.sh
#   - Operates inside envs/aws-dev or envs/gcp-dev (each is a Terraform root).
# Senior notes:
#   - Make is the UX layer; Terraform stays declarative underneath.
#   - Preflight checks shift failures left (bad creds, wrong context).
# ------------------------------------------------------------------------------


SHELL := /bin/bash

# =========================
# Config (override at call)
# =========================
AWS_ENV ?= envs/aws-dev
GCP_ENV ?= envs/gcp-dev
VAR_FILE ?= dev.tfvars

# Optional safety rails: set these to enforce you're in the right org
#   make aws-plan AWS_EXPECTED_ACCOUNT=123456789012
#   make gcp-apply GCP_EXPECTED_PROJECT=my-prod-project
AWS_EXPECTED_ACCOUNT ?=
GCP_EXPECTED_PROJECT ?=

# =========================
# ANSI Colors
# =========================
RESET := \033[0m
BOLD  := \033[1m
DIM   := \033[2m
FG_GREEN  := \033[32m
FG_YELLOW := \033[33m
FG_CYAN   := \033[36m
FG_GRAY   := \033[90m
FG_RED    := \033[31m

# =========================
# Internal helpers
# =========================
define banner
	@printf "$(BOLD)$(FG_CYAN)▶ %s$(RESET) $(FG_GRAY)(env=%s var-file=%s)$(RESET)\n" "$(1)" "$(2)" "$(3)"
endef

define ensure_dir
	@test -d "$(1)" || { printf "$(FG_RED)Error: directory '$(1)' not found.$(RESET)\n"; exit 1; }
endef

# =========================
# Preflight: AWS
# =========================
aws-preflight:
	@set -e; \
	command -v aws >/dev/null 2>&1 || { echo "$(FG_RED)aws CLI not found$(RESET)"; exit 1; }; \
	AWS_ACCT=$$(aws sts get-caller-identity --query Account --output text 2>/dev/null) || { \
		echo "$(FG_RED)aws sts get-caller-identity failed (bad creds/expired)$(RESET)"; exit 1; }; \
	AWS_ARN=$$(aws sts get-caller-identity --query Arn --output text); \
	REGION=$$(aws configure get region 2>/dev/null || echo ""); \
	printf "$(FG_GREEN)AWS OK$(RESET): account=%s  arn=%s  region=%s\n" "$$AWS_ACCT" "$$AWS_ARN" "$$REGION"; \
	if [ -n "$(AWS_EXPECTED_ACCOUNT)" ]; then \
		if [ "$$AWS_ACCT" != "$(AWS_EXPECTED_ACCOUNT)" ]; then \
			echo "$(FG_RED)Refusing to proceed: expected AWS account $(AWS_EXPECTED_ACCOUNT), got $$AWS_ACCT$(RESET)"; \
			exit 1; \
		fi; \
	fi

# =========================
# Preflight: GCP
# =========================
gcp-preflight:
	@set -e; \
	command -v gcloud >/dev/null 2>&1 || { echo "$(FG_RED)gcloud CLI not found$(RESET)"; exit 1; }; \
	PROJECT=$$(gcloud config get-value project 2>/dev/null); \
	ACCOUNTS=$$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null); \
	if [ -z "$$PROJECT" ]; then echo "$(FG_RED)No active GCP project set (gcloud config set project …)$(RESET)"; exit 1; fi; \
	if [ -z "$$ACCOUNTS" ]; then echo "$(FG_RED)No active GCP credentials (gcloud auth list)$(RESET)"; exit 1; fi; \
	printf "$(FG_GREEN)GCP OK$(RESET): project=%s  account=%s\n" "$$PROJECT" "$$ACCOUNTS"; \
	if [ -n "$(GCP_EXPECTED_PROJECT)" ]; then \
		if [ "$$PROJECT" != "$(GCP_EXPECTED_PROJECT)" ]; then \
			echo "$(FG_RED)Refusing to proceed: expected GCP project $(GCP_EXPECTED_PROJECT), got $$PROJECT$(RESET)"; \
			exit 1; \
		fi; \
	fi

# =========================
# AWS
# =========================
aws-init: aws-preflight ## Initialize AWS environment
	$(call ensure_dir,$(AWS_ENV))
	$(call banner,terraform init (AWS),$(AWS_ENV),$(VAR_FILE))
	cd $(AWS_ENV) && terraform init

aws-plan: aws-preflight ## Show AWS plan (using $(VAR_FILE))
	$(call ensure_dir,$(AWS_ENV))
	$(call banner,terraform plan (AWS),$(AWS_ENV),$(VAR_FILE))
	cd $(AWS_ENV) && terraform plan -var-file=$(VAR_FILE)

aws-apply: aws-preflight ## Apply AWS changes (auto-approve)
	$(call ensure_dir,$(AWS_ENV))
	$(call banner,terraform apply (AWS),$(AWS_ENV),$(VAR_FILE))
	cd $(AWS_ENV) && terraform apply -auto-approve -var-file=$(VAR_FILE)

aws-destroy: aws-preflight ## Destroy AWS resources (auto-approve)
	$(call ensure_dir,$(AWS_ENV))
	$(call banner,terraform destroy (AWS),$(AWS_ENV),$(VAR_FILE))
	cd $(AWS_ENV) && terraform destroy -auto-approve -var-file=$(VAR_FILE)

# =========================
# GCP
# =========================
gcp-init: gcp-preflight ## Initialize GCP environment
	$(call ensure_dir,$(GCP_ENV))
	$(call banner,terraform init (GCP),$(GCP_ENV),$(VAR_FILE))
	cd $(GCP_ENV) && terraform init

gcp-plan: gcp-preflight ## Show GCP plan (using $(VAR_FILE))
	$(call ensure_dir,$(GCP_ENV))
	$(call banner,terraform plan (GCP),$(GCP_ENV),$(VAR_FILE))
	cd $(GCP_ENV) && terraform plan -var-file=$(VAR_FILE)

gcp-apply: gcp-preflight ## Apply GCP changes (auto-approve)
	$(call ensure_dir,$(GCP_ENV))
	$(call banner,terraform apply (GCP),$(GCP_ENV),$(VAR_FILE))
	cd $(GCP_ENV) && terraform apply -auto-approve -var-file=$(VAR_FILE)

gcp-destroy: gcp-preflight ## Destroy GCP resources (auto-approve)
	$(call ensure_dir,$(GCP_ENV))
	$(call banner,terraform destroy (GCP),$(GCP_ENV),$(VAR_FILE))
	cd $(GCP_ENV) && terraform destroy -auto-approve -var-file=$(VAR_FILE)

# =========================
# Validation / Policy / Utilities
# =========================
fmt: ## Terraform fmt (recursive)
	@printf "$(FG_CYAN)terraform fmt -recursive$(RESET)\n"
	@terraform fmt -recursive

validate: ## Run Terraform validate script
	@printf "$(FG_CYAN)./scripts/tf-validate.sh$(RESET)\n"
	@./scripts/tf-validate.sh

opa: ## Run OPA policy check
	@printf "$(FG_CYAN)./scripts/opa-eval.sh$(RESET)\n"
	@./scripts/opa-eval.sh

clean-local: ## Remove local .terraform dirs and .tfstate* from envs (non-destructive)
	@printf "$(FG_YELLOW)Cleaning local Terraform artifacts in envs/*$(RESET)\n"
	@find envs -type d -name ".terraform" -prune -exec rm -rf {} + 2>/dev/null || true
	@find envs -type f -name "*.tfstate*" -delete 2>/dev/null || true

# =========================
# Banner (quick info)
# =========================
banner: ## Show current environment variables (AWS/GCP + var-file)
	@printf "\n$(BOLD)Terraform Environments$(RESET)\n"
	@printf "  $(FG_GREEN)AWS_ENV$(RESET): $(AWS_ENV)\n"
	@printf "  $(FG_GREEN)GCP_ENV$(RESET): $(GCP_ENV)\n"
	@printf "  $(FG_GREEN)VAR_FILE$(RESET): $(VAR_FILE)\n\n"
	@printf "$(FG_GRAY)Tip: Override with make VAR_FILE=staging.tfvars ...$(RESET)\n\n"

# =========================
# Help (auto-generated)
# =========================
help: ## Show available make commands
	@printf "\n$(BOLD)Available make commands$(RESET)\n"
	@grep -E '^[a-zA-Z0-9_.-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	| sort \
	| awk 'BEGIN {FS = ":.*?## "}; {printf "  $(FG_GREEN)make %-18s$(RESET) $(FG_YELLOW)%s$(RESET)\n", $$1, $$2}'
	@printf "\n$(FG_GRAY)Hints: set AWS_ENV/GCP_ENV/VAR_FILE per run, e.g.:$(RESET)\n"
	@printf "  $(FG_GREEN)make aws-plan AWS_ENV=envs/aws-prod VAR_FILE=prod.tfvars$(RESET)\n"
	@printf "  $(FG_GREEN)make gcp-apply GCP_ENV=envs/gcp-staging VAR_FILE=staging.tfvars$(RESET)\n\n"

.DEFAULT_GOAL := help
.PHONY: aws-preflight gcp-preflight \
        aws-init aws-plan aws-apply aws-destroy \
        gcp-init gcp-plan gcp-apply gcp-destroy \
        fmt validate opa clean-local banner help
