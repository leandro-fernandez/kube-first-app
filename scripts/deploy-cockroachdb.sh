#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Usage: ./scripts/deploy-cockroachdb.sh

Deploy CockroachDB, wait for startup, and test a password login through its Service.
Requires kubectl and a running local Kubernetes cluster.

Optional environment variables:
  KUBE_CONTEXT    Kubernetes context (default: minikube)
  KUBE_NAMESPACE  Existing namespace (default: default)
EOF
  exit 0
fi

if [[ $# -ne 0 ]]; then
  printf 'Unexpected argument. Run with --help for usage.\n' >&2
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  printf 'kubectl is required. Install it before running this script.\n' >&2
  exit 1
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
context="${KUBE_CONTEXT:-minikube}"
namespace="${KUBE_NAMESPACE:-default}"

kube() {
  kubectl --context "$context" --namespace "$namespace" "$@"
}

printf 'Deploying to context %s, namespace %s\n' "$context" "$namespace"
if ! kube get --raw=/readyz --request-timeout=5s >/dev/null 2>&1; then
  printf 'Cannot reach Kubernetes context %s.\n' "$context" >&2
  printf 'For Minikube, run: minikube start\n' >&2
  exit 1
fi

kube apply -f "$repo_root/k8s/base/cockroachdb/"
kube rollout status deployment/cockroachdb-deployment --timeout=180s

db_host="$(kube get configmap cockroachdb-config -o 'go-template={{index .data "cockroach-url"}}')"

# A running Pod may still be initializing its database and user.
printf 'Waiting for a password login through %s...\n' "$db_host"
for ((attempt = 1; attempt <= 30; attempt++)); do
  if result="$(kube exec deployment/cockroachdb-deployment -c cockroachdb -- \
    sh -ec '
      exec /cockroach/cockroach sql \
        --certs-dir=/tmp/no-client-certificates \
        --url="postgresql://${COCKROACH_USER}:${COCKROACH_PASSWORD}@${1}:26257/defaultdb?sslmode=require&connect_timeout=3" \
        --execute="SELECT current_user, current_database();"
    ' sh "$db_host" 2>&1)"; then
    printf '%s\n' "$result"
    printf 'CockroachDB is deployed and the password login succeeded.\n'
    exit 0
  fi
  sleep 2
done

printf 'CockroachDB did not pass its SQL login check:\n%s\n' "$result" >&2
printf 'Inspect startup logs with:\n' >&2
printf 'kubectl --context %q --namespace %q logs deployment/cockroachdb-deployment\n' "$context" "$namespace" >&2
exit 1
