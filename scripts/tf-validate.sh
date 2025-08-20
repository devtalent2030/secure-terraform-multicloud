#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# tf-validate.sh
# Purpose: Validate every env root without touching real backends/state.
# How:
#   - Loops envs/* (multi-env safety net).
#   - Runs `terraform init -backend=false` to download provider schemas ONLY.
#   - Runs `terraform validate` to catch type/arg/deprecation errors early.
# Why:
#   - Fails fast in CI if any env breaks.
#   - Safe for forks: no state access, no credentials required.
# Senior notes:
#   - This catches provider schema drift even when your HCL didn’t change.
#   - Use alongside OPA plan checks for correctness + compliance.
# ------------------------------------------------------------------------------
set -euo pipefail

for d in envs/*; do
  if [[ -d "$d" ]]; then
    echo "==> terraform validate: $d"
    (cd "$d" && terraform init -backend=false -input=false >/dev/null && terraform validate)
  fi
done

set -euo pipefail

for d in envs/*; do
  if [[ -d "$d" ]]; then
    echo "==> terraform validate: $d"
    (
      cd "$d"
      terraform init -backend=false -input=false >/dev/null
      terraform validate
    )
  fi
done
