# Kubernetes First App

An application project for learning and building with Kubernetes.

## CockroachDB exercise

Start your local Minikube cluster, then run the deployment script from the
repository root:

```sh
minikube start
./scripts/deploy-cockroachdb.sh
```

The script uses Bash and `kubectl`. It applies the three manifest files, waits
for the Deployment, and retries a SQL login until database initialization
finishes. The login uses the Pod's credential environment variables and the
Service hostname from the ConfigMap. It prints `cock` and `defaultdb` on success.
It can also be run from another directory using its absolute path.

The default target is context `minikube`, namespace `default`. For another local
cluster, override the context (for example, Docker Desktop):

```sh
KUBE_CONTEXT=docker-desktop ./scripts/deploy-cockroachdb.sh
```

To use an existing namespace, set `KUBE_NAMESPACE`. Run the script with `--help`
to see these options. Re-running it applies manifest changes and checks the
database again; it does not reset data or rotate existing passwords.

The main Kubernetes commands are:

```sh
kubectl --context=minikube apply -f k8s/base/cockroachdb/
kubectl --context=minikube rollout status deployment/cockroachdb-deployment --timeout=180s
kubectl --context=minikube get pods -l app=cockroachdb
kubectl --context=minikube get service cockroachdb-service
kubectl --context=minikube logs deployment/cockroachdb-deployment
```

To remove the exercise resources and their disposable database data:

```sh
kubectl --context=minikube delete -f k8s/base/cockroachdb/
```

The single-node container creates user `cock` with password `cockroach` on its
first startup, using `COCKROACH_USER` and `COCKROACH_PASSWORD` from the Secret.
It generates its own TLS certificates. Initialization only runs on an empty data
directory; changing the Secret later does not update an existing database user.

A web app in the same namespace can connect using:

```text
postgresql://cock:cockroach@cockroachdb-service:26257/defaultdb?sslmode=require
```

For this exercise, `sslmode=require` encrypts the connection without verifying
the generated server certificate. The ConfigMap supplies the hostname; the
Secret supplies the credentials. No persistent storage is configured.

## Tables and sample data

After deploying CockroachDB, run:

```sh
./scripts/migrate-cockroachdb.sh
```

This Bash script runs the SQL files in `migrations/` in filename order against
`defaultdb`, using the same context, namespace, Service and credentials as the
deployment script. It requires only `kubectl`; the SQL client runs inside the
database Pod. `KUBE_CONTEXT` and `KUBE_NAMESPACE` work as above.

| File | Creates |
| --- | --- |
| `001_create_customers.sql` | Customers with a UUID ID, name, unique email and creation timestamp |
| `002_create_orders.sql` | Orders with a UUID ID, unique reference, customer ID, description, decimal price and creation timestamp |
| `003_seed_sample_data.sql` | 100 sample customers and 300 orders assigned randomly among them |

Primary keys default to `gen_random_uuid()`. The orders' customer foreign key is
indexed, and prices cannot be negative. An order's price is its total amount in
one currency for this exercise.

Sample emails are `customer1@example.com` through `customer100@example.com`.
Order references are `ORD-0001` through `ORD-0300`, with random prices from 1.00
to 500.00. Some customers may have no orders; others may have several.

These are simple repeatable SQL scripts, without a migration framework or
migration-history table. Existing tables and sample records are skipped on
reruns, preserving their IDs, customer assignments and prices. The seed file
runs in a transaction. Existing tables are not altered to repair schema drift;
future schema changes should go in new numbered files. The runner stops on SQL
errors. It does not delete existing data.

For a fresh database, the final summary should show 100 customers and 300 orders.
Deploying alone does not run migrations or load sample data.
