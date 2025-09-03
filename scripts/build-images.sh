#!/usr/bin/env bash
set -euo pipefail

# Build and push service images to ECR (linux/amd64)
# Usage: ./scripts/build-images.sh [region] [account_id] [cluster_name]

AWS_REGION=${1:-${AWS_REGION:-us-west-2}}
ACCOUNT_ID=${2:-${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}}
CLUSTER_NAME=${3:-${CLUSTER_NAME:-otel-demo-cluster}}

SERVICES=(productcatalog cart frontend)

echo "[build] Region: $AWS_REGION Account: $ACCOUNT_ID Cluster: $CLUSTER_NAME"

echo "[build] Ensuring ECR repositories exist..."
for svc in "${SERVICES[@]}"; do
  repo="${CLUSTER_NAME}-${svc}"
  if ! aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" >/dev/null 2>&1; then
    aws ecr create-repository --repository-name "$repo" --region "$AWS_REGION" >/dev/null
    echo "[build] Created repo $repo"
  fi
done

echo "[build] Logging into ECR..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Choose builder that supports multi-platform
if ! docker buildx ls | grep -q otelbuilder; then
  docker buildx create --name otelbuilder >/dev/null
fi
docker buildx use otelbuilder

echo "[build] Building and pushing images (linux/amd64)..."
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

for svc in "${SERVICES[@]}"; do
  context="${BASE_DIR}/src/${svc}"
  if [ ! -d "$context" ]; then
    echo "[build][ERROR] Context not found: $context" >&2
    exit 1
  fi
  image="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${CLUSTER_NAME}-${svc}:latest"
  echo "[build] -> $svc => $image"
  docker buildx build --platform linux/amd64 -t "$image" --push "$context"
done

echo "[build] Done. Images pushed."
