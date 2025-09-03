#!/bin/bash

# Deploy Applications to EKS
# This script deploys the OpenTelemetry demo applications to EKS

set -e

# Configuration
AWS_REGION=${AWS_REGION:-us-west-2}
CLUSTER_NAME=${CLUSTER_NAME:-otel-demo-cluster}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if AWS credentials are configured
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_status "Prerequisites check passed!"
}

# Configure kubectl for EKS
configure_kubectl() {
    print_status "Configuring kubectl for EKS cluster..."
    aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
    
    # Verify connection
    if kubectl cluster-info &> /dev/null; then
        print_status "Successfully connected to EKS cluster!"
    else
        print_error "Failed to connect to EKS cluster. Please check your configuration."
        exit 1
    fi
}

# Update image references in Kubernetes manifests
update_image_references() {
    print_status "Updating image references in Kubernetes manifests..."

    local src_file="k8s/deploy-apps.yaml"
    local dst_file="k8s/deploy-apps-updated.yaml"

    if [ ! -f "$src_file" ]; then
        print_error "Source manifest $src_file not found."
        exit 1
    fi

    cp "$src_file" "$dst_file"

    local services=("productcatalog" "cart" "frontend")

    for service in "${services[@]}"; do
        local ecr_repo="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$CLUSTER_NAME-$service:latest"
    # Portable replace without relying on sed -i differences (use temp file)
    local tmp_file
    tmp_file=$(mktemp)
    sed "s|image: $service:latest|image: $ecr_repo|g" "$dst_file" > "$tmp_file" && mv "$tmp_file" "$dst_file"
    done

    print_status "Image references updated successfully! Updated file: $dst_file"
}

# Deploy applications to EKS
deploy_applications() {
    print_status "Deploying applications to EKS..."
    
    # Apply the updated deployment manifest
    kubectl apply -f k8s/deploy-apps-updated.yaml
    
    print_status "Applications deployed successfully!"
    
    # Wait for deployments to be ready
    print_status "Waiting for deployments to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/otel-collector
    kubectl wait --for=condition=available --timeout=300s deployment/productcatalog
    kubectl wait --for=condition=available --timeout=300s deployment/cart
    kubectl wait --for=condition=available --timeout=300s deployment/frontend
    
    print_status "All deployments are ready!"
}

# Get service information
get_service_info() {
    print_status "Getting service information..."
    
    echo ""
    echo "=== Deployed Services ==="
    kubectl get services
    
    echo ""
    echo "=== Pod Status ==="
    kubectl get pods
    
    echo ""
    echo "=== Frontend Service Details ==="
    kubectl describe service frontend
    
    # Get LoadBalancer URL if available
    local lb_hostname=$(kubectl get service frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ -n "$lb_hostname" ]; then
        print_status "Frontend is accessible at: http://$lb_hostname:8080"
    else
        print_warning "LoadBalancer is still provisioning. Run 'kubectl get service frontend' to check status."
        print_status "You can also use port-forward to access the frontend:"
        print_status "kubectl port-forward service/frontend 8080:8080"
    fi
}

# Main execution
main() {
    print_status "Starting deployment to EKS..."

    if [ "${BUILD_IMAGES:-false}" = "true" ]; then
        print_status "BUILD_IMAGES=true -> Building service images before deployment"
        "$(dirname "$0")/build-images.sh" "$AWS_REGION" "$AWS_ACCOUNT_ID" "$CLUSTER_NAME"
    else
        print_status "Skipping image build (set BUILD_IMAGES=true to enable)"
    fi
    
    # Check prerequisites
    check_prerequisites
    
    # Configure kubectl
    configure_kubectl
    
    # Update image references
    update_image_references
    
    # Deploy applications
    deploy_applications
    
    # Get service information
    get_service_info
    
    print_status "Deployment completed successfully!"
    print_status "You can monitor the applications using:"
    print_status "  kubectl get pods -w"
    print_status "  kubectl logs -f deployment/frontend"
    print_status "  kubectl logs -f deployment/otel-collector"
}

# Run main function
main "$@"

