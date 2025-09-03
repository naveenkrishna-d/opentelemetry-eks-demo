# OpenTelemetry EKS Demo - Troubleshooting Guide

This guide helps diagnose and resolve common issues encountered when deploying and running the OpenTelemetry EKS demo.

## Common Issues and Solutions

### Infrastructure Issues

#### Issue: Terraform Apply Fails
**Symptoms:**
- Terraform reports resource creation errors
- AWS API rate limiting errors
- Permission denied errors

**Solutions:**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify required permissions
aws iam simulate-principal-policy \
  --policy-source-arn $(aws sts get-caller-identity --query Arn --output text) \
  --action-names eks:CreateCluster ec2:CreateVpc iam:CreateRole

# Retry with specific resource targeting
terraform apply -target=aws_vpc.main
```

#### Issue: EKS Cluster Creation Timeout
**Symptoms:**
- Cluster creation takes longer than expected
- Timeout errors during cluster provisioning

**Solutions:**
```bash
# Check cluster status
aws eks describe-cluster --name otel-demo-cluster --region us-west-2

# Monitor CloudFormation stack (EKS uses CloudFormation internally)
aws cloudformation describe-stacks --region us-west-2

# Increase timeout in Terraform configuration if needed
```

### Container and Image Issues

#### Issue: Image Pull Errors
**Symptoms:**
- Pods stuck in `ImagePullBackOff` state
- ECR authentication failures

**Solutions:**
```bash
# Check ECR repositories
aws ecr describe-repositories --region us-west-2

# Verify image tags
aws ecr list-images --repository-name otel-demo-cluster-frontend --region us-west-2

# Re-authenticate Docker with ECR
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-west-2.amazonaws.com

# Rebuild and push images
./scripts/build-and-push.sh
```

#### Issue: Container Build Failures
**Symptoms:**
- Docker build errors
- Missing dependencies in containers

**Solutions:**
```bash
# Check Docker daemon status
docker info

# Build images individually for debugging
cd src/frontend
docker build -t frontend:debug .

# Check build logs for specific errors
docker build --no-cache -t frontend:debug . 2>&1 | tee build.log
```

### Kubernetes Deployment Issues

#### Issue: Pods Not Starting
**Symptoms:**
- Pods in `Pending`, `CrashLoopBackOff`, or `Error` state
- Resource allocation failures

**Solutions:**
```bash
# Check pod status and events
kubectl describe pod <pod-name>

# Check node resources
kubectl top nodes
kubectl describe nodes

# Check resource quotas
kubectl describe resourcequota

# Adjust resource requests if needed
kubectl patch deployment frontend -p '{"spec":{"template":{"spec":{"containers":[{"name":"frontend","resources":{"requests":{"cpu":"50m","memory":"64Mi"}}}]}}}}'
```

#### Issue: Service Discovery Problems
**Symptoms:**
- Services cannot communicate with each other
- DNS resolution failures

**Solutions:**
```bash
# Test DNS resolution
kubectl exec -it <pod-name> -- nslookup productcatalog
kubectl exec -it <pod-name> -- nslookup kubernetes.default

# Check service endpoints
kubectl get endpoints
kubectl describe service <service-name>

# Test connectivity between pods
kubectl exec -it <frontend-pod> -- curl http://productcatalog:7000/health
```

### OpenTelemetry Issues

#### Issue: No Traces in Jaeger
**Symptoms:**
- Jaeger UI shows no services or traces
- Applications appear to be running but no telemetry data

**Solutions:**
```bash
# Check OpenTelemetry Collector logs
kubectl logs deployment/otel-collector -f

# Verify collector configuration
kubectl get configmap otel-collector-config -o yaml

# Check application instrumentation
kubectl logs deployment/frontend | grep -i "opentelemetry\|trace"

# Test collector endpoints
kubectl port-forward service/otel-collector 4317:4317
# Use grpcurl or similar tool to test OTLP endpoint

# Verify Jaeger connectivity
kubectl port-forward service/jaeger-collector 14250:14250
```

#### Issue: Missing Metrics in Prometheus
**Symptoms:**
- Prometheus shows no targets or metrics
- Metrics endpoints not accessible

**Solutions:**
```bash
# Check Prometheus targets
kubectl port-forward service/prometheus 9090:9090
# Navigate to Status > Targets in Prometheus UI

# Verify OpenTelemetry Collector metrics endpoint
kubectl port-forward service/otel-collector 8889:8889
curl http://localhost:8889/metrics

# Check Prometheus configuration
kubectl get configmap prometheus-config -o yaml

# Restart Prometheus to reload configuration
kubectl rollout restart deployment/prometheus
```

### Application Issues

#### Issue: Frontend Not Accessible
**Symptoms:**
- LoadBalancer service not getting external IP
- Connection timeouts to frontend

**Solutions:**
```bash
# Check LoadBalancer status
kubectl get service frontend -w

# Check AWS Load Balancer Controller (if installed)
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Use port forwarding as alternative
kubectl port-forward service/frontend 8080:8080

# Check security groups
aws ec2 describe-security-groups --filters "Name=tag:kubernetes.io/cluster/otel-demo-cluster,Values=owned"
```

#### Issue: Service Communication Failures
**Symptoms:**
- HTTP 500 errors in frontend
- Services cannot reach downstream dependencies

**Solutions:**
```bash
# Check service logs
kubectl logs deployment/frontend -f
kubectl logs deployment/productcatalog -f
kubectl logs deployment/cart -f

# Test service endpoints individually
kubectl port-forward service/productcatalog 7000:7000
curl http://localhost:7000/health

# Check network policies
kubectl get networkpolicies
kubectl describe networkpolicy <policy-name>
```

### Observability Stack Issues

#### Issue: Grafana Login Problems
**Symptoms:**
- Cannot access Grafana UI
- Authentication failures

**Solutions:**
```bash
# Check Grafana pod status
kubectl get pods -l app=grafana
kubectl logs deployment/grafana

# Reset admin password
kubectl exec -it deployment/grafana -- grafana-cli admin reset-admin-password newpassword

# Check Grafana configuration
kubectl get configmap grafana-config -o yaml
```

#### Issue: Dashboard Data Not Loading
**Symptoms:**
- Grafana dashboards show no data
- Data source connection errors

**Solutions:**
```bash
# Test data source connectivity from Grafana pod
kubectl exec -it deployment/grafana -- curl http://prometheus:9090/api/v1/query?query=up

# Check data source configuration
kubectl get configmap grafana-datasources -o yaml

# Verify Prometheus is collecting metrics
kubectl port-forward service/prometheus 9090:9090
# Check targets and metrics in Prometheus UI
```

## Diagnostic Commands

### System Health Check
```bash
#!/bin/bash
echo "=== Cluster Status ==="
kubectl cluster-info
kubectl get nodes

echo "=== Pod Status ==="
kubectl get pods -o wide

echo "=== Service Status ==="
kubectl get services

echo "=== Recent Events ==="
kubectl get events --sort-by=.metadata.creationTimestamp | tail -10

echo "=== Resource Usage ==="
kubectl top nodes
kubectl top pods
```

### OpenTelemetry Health Check
```bash
#!/bin/bash
echo "=== OpenTelemetry Collector Status ==="
kubectl logs deployment/otel-collector --tail=20

echo "=== Application Instrumentation Check ==="
kubectl logs deployment/frontend --tail=10 | grep -i opentelemetry
kubectl logs deployment/productcatalog --tail=10 | grep -i opentelemetry
kubectl logs deployment/cart --tail=10 | grep -i opentelemetry

echo "=== Jaeger Connectivity ==="
kubectl port-forward service/jaeger-ui 16686:16686 &
sleep 2
curl -s http://localhost:16686/api/services | jq .
kill %1
```

### Network Connectivity Test
```bash
#!/bin/bash
FRONTEND_POD=$(kubectl get pods -l app=frontend -o jsonpath='{.items[0].metadata.name}')

echo "=== DNS Resolution Test ==="
kubectl exec $FRONTEND_POD -- nslookup productcatalog
kubectl exec $FRONTEND_POD -- nslookup cart
kubectl exec $FRONTEND_POD -- nslookup otel-collector

echo "=== Service Connectivity Test ==="
kubectl exec $FRONTEND_POD -- curl -s http://productcatalog:7000/health
kubectl exec $FRONTEND_POD -- curl -s http://cart:7001/health
kubectl exec $FRONTEND_POD -- curl -s http://otel-collector:13133/
```

## Getting Help

If you continue to experience issues:

1. **Check the logs**: Always start with `kubectl logs` for the affected components
2. **Review the documentation**: Ensure you've followed all setup steps correctly
3. **Search existing issues**: Check the GitHub repository for similar problems
4. **Create a detailed issue**: Include logs, error messages, and reproduction steps
5. **Join the community**: Engage with the OpenTelemetry community for broader support

## Emergency Cleanup

If the system is in an unrecoverable state:

```bash
# Force delete all resources
kubectl delete --all deployments
kubectl delete --all services
kubectl delete --all configmaps
kubectl delete --all pods --force --grace-period=0

# Destroy infrastructure
cd terraform
terraform destroy -auto-approve

# Clean up local kubectl context
kubectl config delete-context arn:aws:eks:us-west-2:$(aws sts get-caller-identity --query Account --output text):cluster/otel-demo-cluster
```

