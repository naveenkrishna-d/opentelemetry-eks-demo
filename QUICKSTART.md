# OpenTelemetry EKS Demo – Quick Start (Clean Handoff)

This guide lets a recipient deploy the demo from a fresh clone with minimal steps.

## 1. Prerequisites
Install locally:
- AWS CLI v2
- Terraform >= 1.4
- kubectl (matching EKS version ~1.28)
- Docker
- jq (optional for scripts)
- Git

Authenticate to AWS (IAM user/role with EKS, EC2, IAM, ECR, VPC, CloudWatch permissions):
```sh
aws configure  # set region e.g. us-west-2
aws sts get-caller-identity
```

## 2. Clone
```sh
git clone <repo-url>
cd opentelemetry-eks-demo
```

## 3. Infrastructure
Creates VPC, EKS cluster, node group, ECR repos.
```sh
./scripts/setup-infrastructure.sh
```
Outputs: cluster name, region, node status.

## 4. Build & Push Images
Tags & pushes three microservice images to ECR.
```sh
./scripts/build-and-push.sh
```

## 5. Observability Stack
Deploys OpenTelemetry Collector, Jaeger, Prometheus, Grafana.
```sh
./scripts/deploy-observability.sh
```

## 6. Application Services
Deploy frontend, productcatalog (Python), cart (Go).
```sh
./scripts/deploy-to-eks.sh
kubectl get pods
```

## 7. Access UIs
If LoadBalancers not exposed externally, port-forward:
```sh
# Jaeger
kubectl port-forward service/jaeger-ui 16686:16686 &
# Grafana
kubectl port-forward service/grafana 3000:3000 &
# Prometheus
kubectl port-forward service/prometheus 9090:9090 &
```
Frontend external URL:
```sh
kubectl get svc frontend -o wide
```

## 8. Generate Sample Traffic
```sh
FRONTEND=$(kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
for i in {1..10}; do curl -s "http://$FRONTEND:8080/api/products" >/dev/null; done
for i in {1..5}; do curl -s -X POST "http://$FRONTEND:8080/api/cart/demo/items" \
  -H 'Content-Type: application/json' -d '{"product_id":"1","quantity":1}' >/dev/null; done
```
View traces in Jaeger (service = frontend). View metrics in Grafana dashboards.

## 9. Teardown (Important)
Destroy resources to avoid cost:
```sh
cd terraform
terraform destroy -auto-approve
```
(Or rerun `setup-infrastructure.sh` later.)

## 10. Troubleshooting Quick Checks
```sh
kubectl get pods
kubectl logs deployment/otel-collector | head
kubectl get svc
```
If no traces: ensure services have OTLP exporter env vars (already set in manifests) and collector pod Ready.

## 11. What’s Included
- Polyglot services (Node / Python / Go) with OpenTelemetry instrumentation.
- Collector pipeline (traces, metrics, logs placeholder) exporting to Jaeger + Prometheus.
- Dashboards (Grafana) + distributed tracing (Jaeger).

## 12. Safety
No credentials committed. Provide your own AWS account and destroy infra after use.

---
For deeper explanation see `README.md`.
