# Deploy Backend to Kubernetes - Step by Step

Complete guide to deploy the Crew Flow backend server to your Kubernetes cluster.

---

## 🎯 Overview

### What Will Be Deployed

- **Application**: Crew Flow Server (Spring Boot)
- **Namespace**: `prod`
- **Image**: `rg.fr-par.scw.cloud/crew-flow/crew-flow-server:prod`
- **Domain**: `crew-flow.api.jibemates.de`
- **Replicas**: 2 (High Availability)

### Architecture

```
Internet
    ↓
Ingress (crew-flow.api.jibemates.de)
    ↓
Service (crew-flow-server)
    ↓
Pods (2 replicas)
    ↓
Database (existing app-db secret)
    ↓
Keycloak (crew-flow.auth.jibemates.de)
```

---

## 📋 Prerequisites

### 1. Kubernetes Cluster Access

```bash
# Verify cluster connection
kubectl cluster-info

# Check namespace
kubectl get namespace prod
```

### 2. Existing Resources

✅ Namespace: `prod`
✅ Database secret: `app-db` (contains JDBC_URL, DB_USERNAME, DB_PASSWORD)
✅ Keycloak: Running at `crew-flow.auth.jibemates.de`
✅ Ingress Controller: nginx
✅ Cert Manager: For SSL certificates

### 3. Scaleway Container Registry

You need:
- Scaleway Secret Key (for pushing/pulling images)
- Get it from: Scaleway Console → IAM → API Keys

---

## 🚀 Quick Deployment (Automated)

```bash
cd /Users/nestorsegura/IdeaProjects/infra-crew-flow

# Run the deployment script
./scripts/deploy-backend.sh
```

The script will:
1. ✅ Check prerequisites
2. ✅ Create registry pull secret (if needed)
3. ✅ Build Docker image
4. ✅ Push to Scaleway registry
5. ✅ Deploy to Kubernetes
6. ✅ Verify health

---

## 📝 Manual Deployment

### Step 1: Create Registry Pull Secret

```bash
# Replace YOUR_SCW_SECRET_KEY with your actual key
kubectl create secret docker-registry scaleway-registry-secret \
  --docker-server=rg.fr-par.scw.cloud \
  --docker-username=nologin \
  --docker-password=YOUR_SCW_SECRET_KEY \
  -n prod
```

### Step 2: Build and Push Docker Image

```bash
# Navigate to backend repository
cd /Users/nestorsegura/IdeaProjects/crew-flow-server

# Build image
docker build -t rg.fr-par.scw.cloud/crew-flow/crew-flow-server:prod .

# Login to Scaleway registry
docker login rg.fr-par.scw.cloud -u nologin -p YOUR_SCW_SECRET_KEY

# Push image
docker push rg.fr-par.scw.cloud/crew-flow/crew-flow-server:prod
```

### Step 3: Apply ConfigMap

```bash
cd /Users/nestorsegura/IdeaProjects/infra-crew-flow

# Apply ConfigMap
kubectl apply -f kubernetes/backend/overlays/production/configmap.yaml -n prod
```

**ConfigMap contains**:
- Spring profiles
- Keycloak URLs
- Database configuration (non-sensitive)
- Actuator settings

### Step 4: Apply Secret

```bash
# Apply Secret
kubectl apply -f kubernetes/backend/overlays/production/secret.yaml -n prod
```

**Secret contains**:
- Keycloak Admin Client Secret
- Database credentials are pulled from existing `app-db` secret

### Step 5: Deploy Application

```bash
# Deploy using Kustomize
kubectl apply -k kubernetes/backend/overlays/production -n prod
```

This will create:
- ✅ Deployment (2 replicas)
- ✅ Service (ClusterIP)
- ✅ Ingress (HTTPS)

### Step 6: Wait for Deployment

```bash
# Watch rollout
kubectl rollout status deployment/crew-flow-server -n prod

# Check pods
kubectl get pods -n prod -l app=crew-flow-server
```

Expected output:
```
NAME                                 READY   STATUS    RESTARTS   AGE
crew-flow-server-xxxxxxxxx-xxxxx    1/1     Running   0          2m
crew-flow-server-xxxxxxxxx-xxxxx    1/1     Running   0          2m
```

### Step 7: Verify Deployment

```bash
# Check all resources
kubectl get all -n prod -l app=crew-flow-server

# Check ingress
kubectl get ingress -n prod crew-flow-server-ingress

# Check logs
kubectl logs -n prod -l app=crew-flow-server --tail=100
```

### Step 8: Test Health Endpoint

```bash
# From within cluster
kubectl run curl-test --rm -i --restart=Never --image=curlimages/curl -n prod -- \
  curl http://crew-flow-server:8080/actuator/health

# Expected output:
# {"status":"UP"}
```

Wait a few minutes for DNS and SSL certificate, then:

```bash
# From internet
curl https://crew-flow.api.jibemates.de/actuator/health
```

---

## 🔍 Configuration Details

### Database Connection

The application uses the existing `app-db` secret:

```yaml
env:
  - name: SPRING_DATASOURCE_URL
    valueFrom:
      secretKeyRef:
        name: app-db
        key: JDBC_URL
  - name: SPRING_DATASOURCE_USERNAME
    valueFrom:
      secretKeyRef:
        name: app-db
        key: DB_USERNAME
  - name: SPRING_DATASOURCE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: app-db
        key: DB_PASSWORD
```

### Keycloak Integration

**ConfigMap settings**:
```yaml
SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI: "https://crew-flow.auth.jibemates.de/realms/crew-flow"
KEYCLOAK_ADMIN_BASE_URL: "https://crew-flow.auth.jibemates.de"
KEYCLOAK_ADMIN_REALM: "crew-flow"
KEYCLOAK_ADMIN_CLIENT_ID: "crew-flow-api"
```

**Secret settings**:
```yaml
KEYCLOAK_ADMIN_CLIENT_SECRET: "your-client-secret"
```

### Resource Allocation

Per pod:
- **Requests**: 512Mi RAM, 250m CPU
- **Limits**: 1Gi RAM, 1000m CPU

Total (2 replicas):
- **Requests**: 1Gi RAM, 500m CPU
- **Limits**: 2Gi RAM, 2000m CPU

### Health Checks

- **Liveness**: `/actuator/health/liveness` (restart if fails)
- **Readiness**: `/actuator/health/readiness` (remove from LB if fails)
- **Startup**: 120s max startup time

---

## 🛠️ Common Operations

### View Logs

```bash
# All pods
kubectl logs -n prod -l app=crew-flow-server -f --tail=100

# Specific pod
kubectl logs -n prod POD_NAME -f
```

### Restart Deployment

```bash
kubectl rollout restart deployment/crew-flow-server -n prod
```

### Scale Deployment

```bash
# Scale to 3 replicas
kubectl scale deployment crew-flow-server --replicas=3 -n prod
```

### Update Configuration

```bash
# Edit ConfigMap
kubectl edit configmap crew-flow-server-config -n prod

# Or update file and apply
kubectl apply -f kubernetes/backend/overlays/production/configmap.yaml -n prod

# Restart pods to pick up changes
kubectl rollout restart deployment/crew-flow-server -n prod
```

### Rollback Deployment

```bash
# View history
kubectl rollout history deployment/crew-flow-server -n prod

# Rollback to previous
kubectl rollout undo deployment/crew-flow-server -n prod

# Rollback to specific revision
kubectl rollout undo deployment/crew-flow-server -n prod --to-revision=2
```

### Port Forward for Testing

```bash
# Forward to localhost
kubectl port-forward -n prod svc/crew-flow-server 8080:8080

# Test locally
curl http://localhost:8080/actuator/health
```

---

## 🔐 Security

### TLS Certificate

SSL certificate is automatically created by cert-manager:

```bash
# Check certificate
kubectl get certificate -n prod crew-flow-api-tls

# Check certificate details
kubectl describe certificate -n prod crew-flow-api-tls
```

If certificate fails:
```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Delete and recreate certificate
kubectl delete certificate -n prod crew-flow-api-tls
kubectl delete secret -n prod crew-flow-api-tls

# Reapply ingress
kubectl apply -f kubernetes/backend/overlays/production/ingress.yaml -n prod
```

### Secrets Management

All secrets are stored in Kubernetes:

```bash
# List secrets
kubectl get secrets -n prod

# View secret (base64 encoded)
kubectl get secret crew-flow-server-secret -n prod -o yaml

# Decode secret value
kubectl get secret crew-flow-server-secret -n prod \
  -o jsonpath='{.data.KEYCLOAK_ADMIN_CLIENT_SECRET}' | base64 -d
```

---

## 🐛 Troubleshooting

### Problem: Pods Not Starting

```bash
# Describe pod
kubectl describe pod -n prod POD_NAME

# Check events
kubectl get events -n prod --sort-by='.lastTimestamp'

# Common issues:
# - Image pull failed: Check registry secret
# - Database connection failed: Check app-db secret
# - Health check failed: Check logs
```

### Problem: Image Pull Failed

```bash
# Check registry secret exists
kubectl get secret scaleway-registry-secret -n prod

# Recreate secret
kubectl delete secret scaleway-registry-secret -n prod

kubectl create secret docker-registry scaleway-registry-secret \
  --docker-server=rg.fr-par.scw.cloud \
  --docker-username=nologin \
  --docker-password=YOUR_SCW_SECRET_KEY \
  -n prod
```

### Problem: Database Connection Failed

```bash
# Check app-db secret
kubectl get secret app-db -n prod -o yaml

# Verify database credentials
kubectl get secret app-db -n prod -o jsonpath='{.data.JDBC_URL}' | base64 -d

# Test connection from pod
kubectl exec -it -n prod POD_NAME -- /bin/sh
wget -qO- http://localhost:8080/actuator/health
```

### Problem: Ingress Not Working

```bash
# Check ingress
kubectl describe ingress crew-flow-server-ingress -n prod

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Verify DNS
nslookup crew-flow.api.jibemates.de

# Check certificate
kubectl get certificate -n prod
```

### Problem: Health Checks Failing

```bash
# Check logs for errors
kubectl logs -n prod -l app=crew-flow-server --tail=200

# Common issues:
# - Database connection: Check JDBC_URL
# - Flyway migration failed: Check database permissions
# - Keycloak connection: Check network connectivity
```

---

## 📊 Monitoring

### Check Pod Status

```bash
# Watch pods
kubectl get pods -n prod -l app=crew-flow-server -w

# Check resource usage
kubectl top pods -n prod -l app=crew-flow-server
```

### Application Metrics

```bash
# Port forward to access metrics
kubectl port-forward -n prod svc/crew-flow-server 8080:8080

# Access metrics
curl http://localhost:8080/actuator/metrics
curl http://localhost:8080/actuator/prometheus
```

---

## ✅ Verification Checklist

After deployment:

- [ ] Pods are running (2/2 ready)
- [ ] Service is created
- [ ] Ingress is configured
- [ ] SSL certificate is issued
- [ ] Health endpoint returns `{"status":"UP"}`
- [ ] API is accessible via HTTPS
- [ ] Can authenticate with Keycloak
- [ ] Database migrations succeeded
- [ ] Logs show no errors

---

## 🎯 Next Steps

- [ ] Configure monitoring (Prometheus/Grafana)
- [ ] Set up log aggregation
- [ ] Configure alerts
- [ ] Test API endpoints
- [ ] Deploy frontend application
- [ ] Set up CI/CD pipeline

---

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kustomize Documentation](https://kubectl.docs.kubernetes.io/references/kustomize/)
- [Scaleway Kubernetes](https://www.scaleway.com/en/docs/compute/kubernetes/)

---

**Deployment Complete!** 🎉

Your backend server is now running in Kubernetes at:
- **API**: https://crew-flow.api.jibemates.de
- **Health**: https://crew-flow.api.jibemates.de/actuator/health
- **Swagger**: https://crew-flow.api.jibemates.de/swagger-ui.html
