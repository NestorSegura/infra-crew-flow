# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository (`infra-crew-flow`) manages Kubernetes infrastructure for the Crew Flow application using:
- **Kubernetes manifests** for cluster-level resources (cert-manager, ClusterIssuer)
- **Helm charts** for application deployments (primarily Keycloak)
- **SealedSecrets** for secure secret management
- **External managed services** (Scaleway PostgreSQL, container registry)

## Architecture

### Project Structure
```
cluster/
├── cluster-issuer.yaml          # cert-manager ClusterIssuer for Let's Encrypt TLS
├── keycloak/                    # Keycloak identity management
│   ├── values-prod.yaml         # Helm values for production deployment
│   ├── keycloak-sealedsecret.yaml  # Encrypted secrets (admin/DB passwords)
│   ├── jibe-mates-light.jar     # Custom Keycloak theme
│   └── README.md                # Keycloak-specific deployment guide
└── crew-flow-server/
    └── crewflow-script          # Docker registry authentication and deployment script
```

### Key Components

**Keycloak (Identity & Access Management)**
- Deployed via Bitnami Helm chart with 2 replicas for HA
- Uses external Scaleway managed PostgreSQL database (not bundled PostgreSQL)
- Exposed via NGINX ingress at `crew-flow.auth.jibemates.de` with automatic TLS from cert-manager
- Custom theme mounted from ConfigMap (`jibe-mates-light.jar`)
- Metrics and health endpoints enabled

**cert-manager**
- ClusterIssuer named `letsencrypt` configured for ACME HTTP-01 challenge
- Issues TLS certificates for ingress resources
- Private key stored in secret `letsencrypt-account-key`

**Container Registry**
- Scaleway container registry at `rg.fr-par.scw.cloud/jb-crew-flow-registry`
- Authentication requires access key and secret key (see `cluster/crew-flow-server/crewflow-script`)

## Common Commands

### Kubernetes Validation & Deployment
```bash
# Validate manifests locally (syntax check)
kubectl apply --dry-run=client -f cluster/

# Validate against live cluster APIs
kubectl apply --server-dry-run -f cluster/

# Apply single manifest
kubectl apply -f cluster/cluster-issuer.yaml

# Verify cluster resources
kubectl get crd,ns,issuer,certificate -A
```

### Helm Operations (Keycloak)
```bash
# Render Helm chart locally (no cluster access needed)
helm template keycloak bitnami/keycloak -n keycloak -f cluster/keycloak/values-prod.yaml > /tmp/keycloak.yaml

# Install/upgrade Keycloak
helm upgrade --install keycloak bitnami/keycloak \
  --namespace keycloak \
  -f cluster/keycloak/values-prod.yaml

# Check deployment status
kubectl -n keycloak rollout status deploy/keycloak

# View Keycloak pods and ingress
kubectl -n keycloak get pods,ingress
```

### Debugging
```bash
# Check pod status and events
kubectl -n keycloak describe pod <pod-name>

# View pod logs
kubectl -n keycloak logs -f <pod-name>

# Check certificate status
kubectl get certificate -A
kubectl describe certificate <cert-name> -n <namespace>

# Test ingress connectivity
curl -v https://crew-flow.auth.jibemates.de
```

### SealedSecrets
```bash
# Create a new SealedSecret (requires kubeseal CLI)
kubectl create secret generic keycloak-secrets \
  --from-literal=admin-password='...' \
  --from-literal=db-password='...' \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > cluster/keycloak/keycloak-sealedsecret.yaml
```

## Configuration Management

### Environment-Specific Values
- Add new environments as `cluster/keycloak/values-<env>.yaml` (e.g., `values-staging.yaml`)
- Keep production values in `values-prod.yaml`

### Keycloak Configuration Points
Edit `cluster/keycloak/values-prod.yaml` to modify:
- `externalDatabase.host/port/user/database` — PostgreSQL connection details
- `ingress.hostname` — domain name for Keycloak
- `extraEnvVars.KC_HOSTNAME` — must match ingress hostname
- `replicaCount` — number of replicas for HA
- `resources` — CPU/memory requests and limits

### Secret Management
- **NEVER** commit plaintext secrets or `.env` files to Git
- All sensitive values must use SealedSecrets encrypted by `kubeseal`
- Reference secrets in Helm values via `existingSecret` and `existingSecretPasswordKey`

## Commit Conventions

Use conventional commit format with imperative mood:
- `feat(keycloak): add custom theme support`
- `fix(ingress): correct TLS certificate issuer reference`
- `chore(cluster): update cert-manager ClusterIssuer email`
- `docs(keycloak): document database migration process`

## YAML Style
- 2-space indentation (no tabs)
- kebab-case for filenames (e.g., `cluster-issuer.yaml`)
- One Kubernetes resource per file
- Explicit `namespace` on all namespaced resources
- Include `app.kubernetes.io/*` labels where applicable

## Prerequisites for Deployment

**Cluster Requirements:**
- Kubernetes cluster with kubectl access
- NGINX ingress controller installed
- cert-manager installed with CRDs
- Sealed Secrets controller for SealedSecret decryption

**External Dependencies:**
- Scaleway managed PostgreSQL instance (host: 51.15.86.152:1664)
- Scaleway container registry with valid credentials
- DNS configured to point ingress hostnames to cluster

**Local Tools:**
- `kubectl` — Kubernetes CLI
- `helm` v3 — Helm package manager
- `kubeseal` (optional) — for creating SealedSecrets
- `yamllint` (optional) — for YAML linting
