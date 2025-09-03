#!/bin/bash

# Deploy Observability Stack (Jaeger, Prometheus, Grafana)
# This script deploys the complete observability stack to EKS

set -e

# Configuration
AWS_REGION=${AWS_REGION:-us-west-2}
CLUSTER_NAME=${CLUSTER_NAME:-otel-demo-cluster}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}[OBSERVABILITY]${NC} $1"
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

# Deploy observability stack
deploy_observability() {
    print_status "Deploying observability stack..."
    
    # Apply the observability deployment manifest
    kubectl apply -f k8s/observability/deploy-observability.yaml
    
    print_status "Observability stack deployed successfully!"
    
    # Wait for deployments to be ready
    print_status "Waiting for deployments to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/jaeger
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus
    kubectl wait --for=condition=available --timeout=300s deployment/grafana
    
    print_status "All observability components are ready!"
}

# Get service information
get_service_info() {
    print_status "Getting observability service information..."
    
    echo ""
    echo "=== Observability Services ==="
    kubectl get services | grep -E "(jaeger|prometheus|grafana)"
    
    echo ""
    echo "=== Observability Pods ==="
    kubectl get pods | grep -E "(jaeger|prometheus|grafana)"
    
    echo ""
    echo "=== Service Details ==="
    
    # Jaeger UI
    local jaeger_lb=$(kubectl get service jaeger-ui -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -n "$jaeger_lb" ]; then
        print_status "Jaeger UI is accessible at: http://$jaeger_lb:16686"
    else
        print_warning "Jaeger LoadBalancer is still provisioning."
        print_status "You can use port-forward: kubectl port-forward service/jaeger-ui 16686:16686"
    fi
    
    # Prometheus
    local prometheus_lb=$(kubectl get service prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -n "$prometheus_lb" ]; then
        print_status "Prometheus is accessible at: http://$prometheus_lb:9090"
    else
        print_warning "Prometheus LoadBalancer is still provisioning."
        print_status "You can use port-forward: kubectl port-forward service/prometheus 9090:9090"
    fi
    
    # Grafana
    local grafana_lb=$(kubectl get service grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -n "$grafana_lb" ]; then
        print_status "Grafana is accessible at: http://$grafana_lb:3000"
        print_status "Default credentials: admin/admin123"
    else
        print_warning "Grafana LoadBalancer is still provisioning."
        print_status "You can use port-forward: kubectl port-forward service/grafana 3000:3000"
    fi
}

# Display usage instructions
display_usage_instructions() {
    print_header "Observability Stack Usage"
    echo ""
    echo "The observability stack has been deployed with the following components:"
    echo ""
    echo "1. Jaeger (Distributed Tracing):"
    echo "   - UI: Access via LoadBalancer or port-forward"
    echo "   - View traces from your microservices"
    echo "   - Analyze request flows and performance bottlenecks"
    echo ""
    echo "2. Prometheus (Metrics Collection):"
    echo "   - UI: Access via LoadBalancer or port-forward"
    echo "   - Query metrics using PromQL"
    echo "   - Monitor application and infrastructure metrics"
    echo ""
    echo "3. Grafana (Visualization):"
    echo "   - UI: Access via LoadBalancer or port-forward"
    echo "   - Username: admin, Password: admin123"
    echo "   - Pre-configured with Prometheus and Jaeger data sources"
    echo "   - Create custom dashboards for your metrics"
    echo ""
    echo "To check LoadBalancer status:"
    echo "  kubectl get services | grep LoadBalancer"
    echo ""
    echo "To use port-forwarding (if LoadBalancers are not ready):"
    echo "  kubectl port-forward service/jaeger-ui 16686:16686 &"
    echo "  kubectl port-forward service/prometheus 9090:9090 &"
    echo "  kubectl port-forward service/grafana 3000:3000 &"
    echo ""
}

# Main execution
main() {
    print_header "Deploying Observability Stack to EKS"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Configure kubectl
    configure_kubectl
    
    # Deploy observability stack
    deploy_observability
    
    # Get service information
    get_service_info
    
    # Display usage instructions
    display_usage_instructions
    
    print_status "Observability stack deployment completed successfully!"
    print_status "You can now deploy your applications and start generating telemetry data."
}

# Run main function
main "$@"

