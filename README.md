# Kubernetes First App

An application project for learning and building with Kubernetes.

## CockroachDB exercise

Apply the manifests:

```sh
kubectl apply -f k8s/base/cockroachdb/
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
