# OpenTelemetry EKS Demo - Deployment Guide

This guide provides step-by-step instructions for deploying the OpenTelemetry demonstration on AWS EKS.

## Pre-Deployment Checklist

Before starting the deployment, ensure you have completed the following:

- [ ] AWS account with appropriate permissions
- [ ] AWS CLI configured with valid credentials
- [ ] Terraform installed (version 1.0+)
- [ ] kubectl installed and configured
- [ ] Docker installed and running
- [ ] Git installed for repository access
- [ ] Sufficient AWS credits or budget ($100+ recommended)

## Deployment Steps

### 1. Infrastructure Provisioning

```bash
# Clone the repository
git clone <repository-url>
cd opentelemetry-eks-demo

# Run the infrastructure setup script
./scripts/setup-infrastructure.sh
```

This script will:
- Validate prerequisites
- Display cost estimates
- Initialize and apply Terraform configuration
- Configure kubectl for the new EKS cluster

### 2. Container Image Management

```bash
# Build and push application images to ECR
./scripts/build-and-push.sh
```

This process:
- Builds Docker images for all three services
- Authenticates with ECR
- Pushes images with appropriate tags

### 3. Observability Stack Deployment

```bash
# Deploy Jaeger, Prometheus, and Grafana
./scripts/deploy-observability.sh
```

This deployment includes:
- Jaeger for distributed tracing
- Prometheus for metrics collection
- Grafana for visualization

### 4. Application Deployment

```bash
# Deploy the microservices application
./scripts/deploy-to-eks.sh
```

This step:
- Updates image references in Kubernetes manifests
- Deploys the OpenTelemetry Collector
- Deploys all application services

### 5. Verification

```bash
# Check deployment status
kubectl get pods
kubectl get services

# Access the application
kubectl get service frontend
```

## Post-Deployment Configuration

### Accessing Services

**Frontend Application**
- Get LoadBalancer URL: `kubectl get service frontend`
- Or use port forwarding: `kubectl port-forward service/frontend 8080:8080`

**Jaeger UI**
- Port forward: `kubectl port-forward service/jaeger-ui 16686:16686`
- Access: http://localhost:16686

**Grafana Dashboard**
- Port forward: `kubectl port-forward service/grafana 3000:3000`
- Access: http://localhost:3000 (admin/admin123)

**Prometheus**
- Port forward: `kubectl port-forward service/prometheus 9090:9090`
- Access: http://localhost:9090

### Initial Testing

Generate test traffic to verify the observability pipeline:

```bash
# Basic functionality test
curl http://<frontend-url>:8080/health
curl http://<frontend-url>:8080/api/products

# Add items to cart
curl -X POST http://<frontend-url>:8080/api/cart/testuser/items \
  -H "Content-Type: application/json" \
  -d '{"product_id":"OLJCESPC7Z","quantity":1}'
```

## Troubleshooting Common Issues

### Pods Not Starting
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Services Not Accessible
```bash
kubectl get services
kubectl get endpoints
kubectl describe service <service-name>
```

### No Traces in Jaeger
```bash
kubectl logs deployment/otel-collector
kubectl logs deployment/frontend | grep -i opentelemetry
```

## Cleanup

When finished with the demo:

```bash
cd terraform
terraform destroy
```

Verify all resources are removed:
```bash
aws eks list-clusters --region us-west-2
aws ec2 describe-vpcs --region us-west-2 --filters "Name=tag:Project,Values=opentelemetry-eks-demo"
```

