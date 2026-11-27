#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Usage: ./scripts/migrate-cockroachdb.sh

Run migrations/*.sql in filename order against the deployed CockroachDB instance.
Deploy first with ./scripts/deploy-cockroachdb.sh.

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

sql() {
  kube exec -i deployment/cockroachdb-deployment -c cockroachdb -- \
    sh -ec '
      exec /cockroach/cockroach sql \
        --certs-dir=/tmp/no-client-certificates \
        --url="postgresql://${COCKROACH_USER}:${COCKROACH_PASSWORD}@${1}:26257/defaultdb?sslmode=require&connect_timeout=10" \
        --set=errexit=true
    ' sh "$db_host"
}

printf 'Migrating context %s, namespace %s\n' "$context" "$namespace"
kube rollout status deployment/cockroachdb-deployment --timeout=180s
db_host="$(kube get configmap cockroachdb-config -o 'go-template={{index .data "cockroach-url"}}')"

for migration in "$repo_root"/migrations/*.sql; do
  printf 'Running %s\n' "${migration##*/}"
  sql < "$migration"
done

sql <<'SQL'
SELECT 'customers' AS table_name, count(*) AS row_count FROM customers
UNION ALL
SELECT 'orders', count(*) FROM orders;
SQL
printf 'Migrations completed successfully.\n'
