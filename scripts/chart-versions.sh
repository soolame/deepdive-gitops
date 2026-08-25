#!/usr/bin/env bash
# Resolves the latest version of every upstream chart referenced in apps/
# and prints the pin you should paste in. Nothing is guessed.
set -euo pipefail

declare -A REPOS=(
  [cnpg]="https://cloudnative-pg.github.io/charts"
  [redpanda]="https://charts.redpanda.com"
  [cloudpirates]="https://cloudpirates-io.github.io/helm-charts"
)
for name in "${!REPOS[@]}"; do
  helm repo add "$name" "${REPOS[$name]}" >/dev/null 2>&1 || true
done
helm repo update >/dev/null

check () {  # $1 app-file  $2 repo-alias  $3 chart
  printf '%-22s ' "$1"
  v=$(helm search repo "$2/$3" --output json 2>/dev/null \
       | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
  if [ -n "${v:-}" ]; then
    echo "-> $v    (sed -i '' 's/TODO-PIN/$v/' apps/$1.yaml)"
  else
    echo "NOT FOUND - chart name or repo is wrong, fix apps/$1.yaml"
  fi
}

check cloudnative-pg    cnpg         cloudnative-pg
check redpanda-operator redpanda     operator
check valkey            cloudpirates valkey
