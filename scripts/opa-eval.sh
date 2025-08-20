#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Policy-as-code evaluation using OPA (Rego).
#
# Behavior:
# - If a plan JSON exists in policy/inputs/*.plan.json, evaluate that (real plan).
# - Else, evaluate example input policy/opa-input.example.json (smoke test).
# - Fails (exit 1) if any deny rules trigger.
#
# Why:
# - Shift-left compliance: block insecure changes BEFORE terraform apply.
# - Usable locally and in CI (no secrets needed to eval policies).
# ------------------------------------------------------------------------------

set -euo pipefail

INPUT=""
# Pick the first available plan JSON if present
if compgen -G "policy/inputs/*.plan.json" > /dev/null; then
  INPUT=$(ls policy/inputs/*.plan.json | head -n1)
else
  INPUT="policy/opa-input.example.json"
fi

echo "OPA evaluating input: $INPUT"

# Count violations (deny messages)
COUNT=$(opa eval -f raw -i "$INPUT" -d policy 'count(data.policy.deny)')
echo "deny count: $COUNT"

# If violations, print them pretty and fail
if [[ "$COUNT" != "0" ]]; then
  echo
  echo "Violations:"
  opa eval -f pretty -i "$INPUT" -d policy 'data.policy.deny'
  echo
  echo "❌ Policy violations found. Failing."
  exit 1
fi

echo "✅ No policy violations."
