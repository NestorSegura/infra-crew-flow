# Keycloak (Helm) Deployment

Production-focused Helm configuration for Keycloak using a managed PostgreSQL database (Scaleway).

## Prerequisites
- Kubernetes cluster with an ingress controller (e.g., NGINX) and `cert-manager` (ClusterIssuer `letsencrypt-prod`).
- Managed PostgreSQL instance reachable from the cluster.
- Helm v3 installed locally.

## Files
- `values-prod.yaml` — Helm values for production with external DB.
- `secret.sample.yaml` — example Secret manifest. Do NOT commit real secrets.

## Install
1) Create namespace and secrets (edit placeholders):
```
kubectl create namespace keycloak
kubectl apply -f cluster/keycloak/secret.sample.yaml
```

2) Add chart repo and deploy:
```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm upgrade --install keycloak bitnami/keycloak \
  --namespace keycloak \
  -f cluster/keycloak/values-prod.yaml
```

## Post-Deploy
- Wait for pods: `kubectl -n keycloak rollout status deploy/keycloak`
- Verify ingress/TLS: `kubectl -n keycloak get ingress` then browse `https://auth.example.com`.

## Configuration
- Edit `values-prod.yaml` and set:
  - `externalDatabase.host`, `user`, `database`
  - ingress `hostname` and TLS `secretName`
  - `extraEnvVars.KC_HOSTNAME` to your domain
- For Scaleway DB, SSL is required; `KC_DB_URL_PARAMETERS: sslmode=require` is set.

## Upgrading
```
helm upgrade keycloak bitnami/keycloak -n keycloak -f cluster/keycloak/values-prod.yaml
```
