# Infrastructure Setup Guide

Complete guide for setting up the Crew Flow infrastructure from scratch.

---

## Prerequisites

### Required Tools

- [kubectl](https://kubernetes.io/docs/tasks/tools/) v1.25+
- [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/) v4.5+
- [git](https://git-scm.com/)
- Scaleway account with Kubernetes cluster
- GitHub account with repository access

### Access Requirements

- Kubernetes cluster admin access
- Scaleway Container Registry access
- GitHub repository write access
- GitHub Actions enabled

---

## Step 1: Clone Repository

```bash
git clone git@github.com:NestorSegura/infra-crew-flow.git
cd infra-crew-flow
```

---

## Step 2: Configure Kubernetes Access

### Get Kubeconfig from Scaleway

1. Go to Scaleway Console → Kubernetes
2. Select your cluster
3. Download kubeconfig
4. Configure kubectl:

```bash
# Copy kubeconfig
cp ~/Downloads/kubeconfig.yaml ~/.kube/config

# Verify connection
kubectl cluster-info
kubectl get nodes
```

---

## Step 3: Create Namespace

```bash
# Create production namespace
kubectl create namespace prod

# Verify
kubectl get namespaces
```

---

## Step 4: Configure GitHub Secrets

### Backend Repository (`crew-flow-server`)

Navigate to: **GitHub → crew-flow-server → Settings → Secrets → Actions**

#### Create `SCW_SECRET_KEY`
1. Get Scaleway API secret key
2. Add to GitHub Secrets

#### Create `INFRA_REPO_PAT`
1. Go to GitHub → Settings → Developer settings → Personal access tokens
2. Generate new token (classic)
3. Select scopes: `repo`, `workflow`
4. Copy token
5. Add to GitHub Secrets as `INFRA_REPO_PAT`

### Infrastructure Repository (`infra-crew-flow`)

Navigate to: **GitHub → infra-crew-flow → Settings → Secrets → Actions**

#### Create `KUBE_CONFIG`
```bash
# Encode kubeconfig
cat ~/.kube/config | base64

# On macOS:
cat ~/.kube/config | base64 | pbcopy

# On Linux:
cat ~/.kube/config | base64 -w 0
```

Add the base64-encoded string to GitHub Secrets.

---

## Step 5: Create Kubernetes Secrets

### Registry Pull Secret

```bash
kubectl create secret docker-registry scaleway-registry-secret \
  --docker-server=rg.fr-par.scw.cloud \
  --docker-username=nologin \
  --docker-password=YOUR_SCW_SECRET_KEY \
  -n prod
```

### Application Secret

```bash
# Copy template
cp kubernetes/backend/overlays/production/secret.yaml.example \
   kubernetes/backend/overlays/production/secret.yaml

# Encode your secrets
echo -n "jdbc:postgresql://your-postgres-host:5432/crewflow_prod" | base64
echo -n "your-db-username" | base64
echo -n "your-db-password" | base64
echo -n "your-redis-password" | base64
echo -n "your-keycloak-client-secret" | base64

# Edit secret.yaml with encoded values
vim kubernetes/backend/overlays/production/secret.yaml

# Apply to cluster
kubectl apply -f kubernetes/backend/overlays/production/secret.yaml
```

**⚠️ IMPORTANT**: Never commit `secret.yaml` to Git!

---

## Step 6: Update Configuration

### ConfigMap

Edit environment-specific values:

```bash
vim kubernetes/backend/overlays/production/configmap.yaml
```

Update:
- Keycloak URLs
- Redis host
- Database configuration
- Any environment-specific settings

### Ingress

Edit with your domain:

```bash
vim kubernetes/backend/overlays/production/ingress.yaml
```

Update:
- `host: api.your-domain.com`
- TLS secret name
- CORS allowed origins

---

## Step 7: Initial Deployment

### Apply Manifests

```bash
# Build and preview
kustomize build kubernetes/backend/overlays/production

# Apply to cluster
kustomize build kubernetes/backend/overlays/production | kubectl apply -f -
```

### Verify Deployment

```bash
# Check pods
kubectl get pods -n prod -l app=crew-flow-server

# Check services
kubectl get svc -n prod -l app=crew-flow-server

# Check ingress
kubectl get ingress -n prod

# View logs
kubectl logs -n prod -l app=crew-flow-server --tail=100
```

### Check Health

```bash
# Health check from within cluster
kubectl run curl-test --rm -i --restart=Never --image=curlimages/curl -n prod -- \
  curl http://crew-flow-server:8080/actuator/health
```

Expected output:
```json
{"status":"UP"}
```

---

## Step 8: Configure DNS

### Get Load Balancer IP

```bash
kubectl get ingress crew-flow-server-ingress -n prod
```

### Update DNS Records

Add A record pointing to the load balancer IP:
```
api.your-domain.com → LOAD_BALANCER_IP
```

---

## Step 9: Configure SSL Certificate

### Install cert-manager (if not installed)

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

### Create ClusterIssuer

```bash
kubectl apply -f cluster/cluster-issuer.yaml
```

### Verify Certificate

```bash
# Check certificate
kubectl get certificate -n prod

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

---

## Step 10: Test Deployment

### Test Health Endpoint

```bash
curl https://api.your-domain.com/actuator/health
```

### Test API Endpoints

```bash
# Test with authentication
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://api.your-domain.com/api/v1/clients
```

---

## Step 11: Enable Continuous Deployment

### Push Backend Code

```bash
cd ../crew-flow-server
git add .
git commit -m "Enable CI/CD pipeline"
git push origin main
```

### Monitor GitHub Actions

1. Go to GitHub Actions
2. Watch "Build and Deploy to Production" workflow
3. Check deployment in infrastructure repository

---

## Verification Checklist

- [ ] Kubernetes cluster accessible via kubectl
- [ ] Namespace `prod` created
- [ ] GitHub Secrets configured (both repos)
- [ ] Registry pull secret created
- [ ] Application secrets created and applied
- [ ] ConfigMap updated with environment-specific values
- [ ] Ingress updated with correct domain
- [ ] Initial deployment successful
- [ ] Pods running and healthy
- [ ] DNS configured
- [ ] SSL certificate issued
- [ ] Health endpoint accessible
- [ ] API endpoints working
- [ ] CI/CD pipeline working

---

## Troubleshooting

### Pods Not Starting

```bash
# Describe pod
kubectl describe pod -n prod POD_NAME

# Check events
kubectl get events -n prod --sort-by='.lastTimestamp'

# Check logs
kubectl logs -n prod POD_NAME
```

### Image Pull Errors

```bash
# Verify registry secret
kubectl get secret scaleway-registry-secret -n prod

# Recreate if needed
kubectl delete secret scaleway-registry-secret -n prod
kubectl create secret docker-registry scaleway-registry-secret \
  --docker-server=rg.fr-par.scw.cloud \
  --docker-username=nologin \
  --docker-password=YOUR_SCW_SECRET_KEY \
  -n prod
```

### Database Connection Errors

```bash
# Check secret
kubectl get secret crew-flow-server-secret -n prod -o yaml

# Decode values to verify
kubectl get secret crew-flow-server-secret -n prod \
  -o jsonpath='{.data.SPRING_DATASOURCE_URL}' | base64 -d
```

### DNS Not Resolving

```bash
# Check load balancer
kubectl get svc -n ingress-nginx

# Verify DNS
nslookup api.your-domain.com

# Check ingress
kubectl describe ingress crew-flow-server-ingress -n prod
```

---

## Next Steps

- [ ] Set up monitoring (Prometheus, Grafana)
- [ ] Configure log aggregation
- [ ] Set up alerting
- [ ] Create staging environment
- [ ] Document operational procedures
- [ ] Set up backup strategy

---

## Support

For help:
- Check [Troubleshooting Guide](TROUBLESHOOTING.md)
- Review GitHub Actions logs
- Check Kubernetes events
- Contact DevOps team

---

**Setup Complete!** 🎉

Your infrastructure is ready for continuous deployment.
