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
