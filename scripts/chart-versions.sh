#!/usr/bin/env bash
# Resolves the real version of every upstream chart referenced in apps/.
# No associative arrays: macOS ships bash 3.2.
set -euo pipefail

command -v helm >/dev/null || { echo "helm not installed"; exit 1; }

add () { helm repo add "$1" "$2" >/dev/null 2>&1 || true; }
add cloudpirates https://cloudpirates-io.github.io/helm-charts
echo "updating repo indexes..."
helm repo update >/dev/null 2>&1 || true
echo

# $1 = apps/<file>  $2 = repo alias  $3 = chart name
check () {
  app="$1"; repo="$2"; chart="$3"
  printf '%-20s %-28s ' "$app" "$repo/$chart"
  ver=$(helm search repo "${repo}/${chart}" --output json 2>/dev/null \
        | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4) || ver=""
  if [ -n "$ver" ]; then
    echo "$ver"
    printf '  -> sed -i "" "s/TODO-PIN/%s/" apps/%s.yaml\n' "$ver" "$app"
  else
    echo "NOT FOUND"
    echo "  charts actually in $repo:"
    helm search repo "${repo}/" --output json 2>/dev/null \
      | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | sed 's/^/    /' \
      || echo "    (repo unreachable)"
  fi
  echo
}

check cloudnative-pg    cnpg         cloudnative-pg
check redpanda-operator redpanda     operator
check valkey            cloudpirates valkey

echo "Paste the sed lines above, then: git commit -am 'pin chart versions' && git push"
