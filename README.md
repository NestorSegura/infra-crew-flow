# Crew Flow Infrastructure

Infrastructure as Code (IaC) for the Crew Flow platform, managing Kubernetes deployments, CI/CD pipelines, and cloud resources.

---

## 📁 Repository Structure

```
infra-crew-flow/
├── .github/
│   └── workflows/              # GitHub Actions workflows
│       └── deploy-backend-production.yaml
├── kubernetes/
│   ├── backend/               # Backend service manifests
│   │   ├── base/              # Base Kubernetes resources
│   │   └── overlays/          # Environment-specific overlays
│   │       └── production/    # Production configuration
│   └── keycloak/              # Keycloak identity server
│       ├── base/
│       └── overlays/
│           └── production/
├── docker/                     # Dockerfiles and compose files
├── scripts/                    # Helper scripts
├── docs/                       # Documentation
└── README.md
```

---

## 🚀 Quick Start

### Prerequisites

- `kubectl` configured with cluster access
- GitHub repository secrets configured
- Scaleway Container Registry access

### Deploy Backend to Production

```bash
# Option 1: Trigger via GitHub Actions UI
# Go to: Actions → Deploy Backend to Production → Run workflow

# Option 2: Apply directly with kubectl
kustomize build kubernetes/backend/overlays/production | kubectl apply -f -
```

---

## 🏗️ Infrastructure Components

### Backend Service
- **Path**: `kubernetes/backend/`
- **Technology**: Spring Boot 3.5.5, Java 24
- **Deployment**: 2 replicas, rolling updates, zero downtime
- **Registry**: Scaleway Container Registry
- **Image**: `rg.fr-par.scw.cloud/crew-flow/crew-flow-server`

### Keycloak
- **Path**: `kubernetes/keycloak/`
- **Purpose**: Identity and Access Management
- **Deployment**: Managed via Helm charts

---

## 🔧 Configuration Management

### Structure: Kustomize

We use **Kustomize** for managing Kubernetes configurations:

- **`base/`**: Common resources (deployment, service)
- **`overlays/`**: Environment-specific configurations

### Environments

- **`production/`**: Production environment (namespace: `prod`)
- **`staging/`** (planned): Staging environment
- **`development/`** (planned): Development environment

### Configuration Files

#### ConfigMap (Non-Sensitive)
**Path**: `kubernetes/backend/overlays/production/configmap.yaml`

Contains:
- Spring profiles
- Logging levels
- Database configuration (non-sensitive)
- Keycloak URLs
- Actuator endpoints

#### Secrets (Sensitive)
**Path**: `kubernetes/backend/overlays/production/secret.yaml`

⚠️ **NEVER COMMIT SECRET.YAML TO GIT!**

Create from template:
```bash
cp kubernetes/backend/overlays/production/secret.yaml.example \
   kubernetes/backend/overlays/production/secret.yaml

# Encode values
echo -n "your-value" | base64

# Edit secret.yaml with encoded values
# Apply to cluster
kubectl apply -f kubernetes/backend/overlays/production/secret.yaml
```

---

## 📦 Deployment Pipeline

### Architecture

```
Backend Repo (crew-flow-server)
    ↓ Push to main
    ↓
GitHub Actions: Build & Test
    ↓ Maven tests pass
    ↓
Docker: Build & Push
    ↓ Push to Scaleway Registry
    ↓
Trigger Deployment
    ↓
Infra Repo (infra-crew-flow)
    ↓
GitHub Actions: Deploy
    ↓ Apply Kustomize manifests
    ↓
Kubernetes Cluster
    ↓ Rolling Update
    ↓
✅ Production Deployment
```

### Workflow Files

#### Backend Repository (`crew-flow-server`)
**File**: `.github/workflows/build-and-deploy.yml`

**Stages**:
1. **Test** - Run Maven tests
2. **Build & Push** - Build Docker image, push to Scaleway
3. **Trigger Deployment** - Trigger deployment in infra repo

#### Infrastructure Repository (`infra-crew-flow`)
**File**: `.github/workflows/deploy-backend-production.yaml`

**Stages**:
1. **Checkout** - Clone infra repository
2. **Apply** - Apply Kustomize manifests
3. **Verify** - Check deployment health

---

## 🔐 Secrets Management

### GitHub Secrets

#### Backend Repository Secrets
- `SCW_SECRET_KEY` - Scaleway Container Registry access
- `INFRA_REPO_PAT` - Personal Access Token for triggering infra workflows

#### Infrastructure Repository Secrets
- `KUBE_CONFIG` - Base64-encoded kubeconfig file
- `SCW_SECRET_KEY` - Scaleway Container Registry access (if needed)

### Kubernetes Secrets

#### Registry Pull Secret
```bash
kubectl create secret docker-registry scaleway-registry-secret \
  --docker-server=rg.fr-par.scw.cloud \
  --docker-username=nologin \
  --docker-password=YOUR_SCW_SECRET_KEY \
  -n prod
```

#### Application Secret
```bash
# Create from template
cp kubernetes/backend/overlays/production/secret.yaml.example \
   kubernetes/backend/overlays/production/secret.yaml

# Edit with your values (base64 encoded)
# Apply
kubectl apply -f kubernetes/backend/overlays/production/secret.yaml
```

---

## 🛠️ Common Operations

### Deploy New Version

```bash
# Option 1: Automatic (triggered by backend push to main)
# Push to main branch in crew-flow-server repository

# Option 2: Manual deployment
# GitHub Actions → Deploy Backend to Production → Run workflow
```

### Update Configuration

```bash
# Edit ConfigMap
vim kubernetes/backend/overlays/production/configmap.yaml

# Apply changes
kustomize build kubernetes/backend/overlays/production | kubectl apply -f -

# Restart pods to pick up changes
kubectl rollout restart deployment/crew-flow-server -n prod
```

### Scale Deployment

```bash
# Edit kustomization.yaml
vim kubernetes/backend/overlays/production/kustomization.yaml

# Change replicas count
replicas:
  - name: crew-flow-server
    count: 3

# Apply
kustomize build kubernetes/backend/overlays/production | kubectl apply -f -
```

### Rollback Deployment

```bash
# View rollout history
kubectl rollout history deployment/crew-flow-server -n prod

# Rollback to previous version
kubectl rollout undo deployment/crew-flow-server -n prod

# Rollback to specific revision
kubectl rollout undo deployment/crew-flow-server -n prod --to-revision=3
```

### View Logs

```bash
# All pods
kubectl logs -n prod -l app=crew-flow-server --tail=100 -f

# Specific pod
kubectl logs -n prod POD_NAME -f
```

### Check Status

```bash
# Deployment status
kubectl get deployment crew-flow-server -n prod

# Pods
kubectl get pods -n prod -l app=crew-flow-server

# Services
kubectl get svc -n prod -l app=crew-flow-server

# Ingress
kubectl get ingress -n prod
```

---

## 📊 Monitoring & Health Checks

### Health Endpoints

- **Liveness**: `/actuator/health/liveness`
- **Readiness**: `/actuator/health/readiness`
- **Metrics**: `/actuator/metrics`
- **Prometheus**: `/actuator/prometheus`

### Check Application Health

```bash
# From within cluster
kubectl run curl-test --rm -i --restart=Never --image=curlimages/curl -n prod -- \
  curl http://crew-flow-server:8080/actuator/health

# Port forward for local access
kubectl port-forward -n prod svc/crew-flow-server 8080:8080
# Then: curl http://localhost:8080/actuator/health
```

---

## 🔄 GitOps Workflow

### Making Changes

1. **Update manifests** in this repository
2. **Create pull request** for review
3. **Merge to main** after approval
4. **Deploy via GitHub Actions** or apply manually

### Best Practices

- ✅ Always test changes in staging first (when available)
- ✅ Use pull requests for all changes
- ✅ Document changes in commit messages
- ✅ Keep secrets out of Git (use secret.yaml.example)
- ✅ Use Kustomize overlays for environment-specific config
- ✅ Tag releases for easier rollback

---

## 📚 Documentation

- **[Setup Guide](docs/SETUP.md)** - Initial setup instructions
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Detailed deployment procedures
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Architecture](docs/ARCHITECTURE.md)** - System architecture overview

---

## 🤝 Contributing

1. Create a feature branch
2. Make your changes
3. Test in development/staging environment
4. Create a pull request
5. Get review and approval
6. Merge to main

---

## 📞 Support

For issues or questions:
- Check [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- Review GitHub Actions workflow runs
- Check Kubernetes events: `kubectl get events -n prod`

---

## 📝 License

Internal use only - Crew Flow Platform

---

**Maintained by**: Crew Flow DevOps Team
**Last Updated**: 2025-01-09
