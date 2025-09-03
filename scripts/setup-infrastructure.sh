#!/bin/bash

# Setup EKS Infrastructure for OpenTelemetry Demo
# This script provisions the complete AWS infrastructure using Terraform

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
    echo -e "${BLUE}[SETUP]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v aws &> /dev/null; then
        missing_tools+=("aws-cli")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "The following tools are missing:"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        print_error "Please install the missing tools and try again."
        exit 1
    fi
    
    # Check if AWS credentials are configured
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_status "Prerequisites check passed!"
}

# Estimate costs
estimate_costs() {
    print_header "Cost Estimation"
    echo ""
    echo "Estimated monthly costs for this demo (us-west-2):"
    echo "  - EKS Cluster: ~$73/month"
    echo "  - EC2 Instances (2x t3.small): ~$30/month"
    echo "  - NAT Gateway: ~$32/month"
    echo "  - EBS Storage: ~$2/month"
    echo "  - Data Transfer: ~$5/month"
    echo "  - ECR Storage: ~$1/month"
    echo ""
    echo "Total estimated cost: ~$143/month"
    echo ""
    print_warning "This exceeds the $100 credit limit. Consider:"
    print_warning "  - Using t3.micro instances (may have performance limitations)"
    print_warning "  - Running for shorter periods"
    print_warning "  - Destroying resources when not in use"
    echo ""
}

# Initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."
    cd terraform
    terraform init
    cd ..
    print_status "Terraform initialized successfully!"
}

# Plan Terraform deployment
plan_terraform() {
    print_status "Planning Terraform deployment..."
    cd terraform
    terraform plan -var="aws_region=$AWS_REGION" -var="cluster_name=$CLUSTER_NAME"
    cd ..
    print_status "Terraform plan completed!"
}

# Apply Terraform configuration
apply_terraform() {
    print_status "Applying Terraform configuration..."
    print_warning "This will create AWS resources that may incur charges."
    
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled."
        exit 0
    fi
    
    cd terraform
    terraform apply -var="aws_region=$AWS_REGION" -var="cluster_name=$CLUSTER_NAME" -auto-approve
    cd ..
    
    print_status "Infrastructure provisioned successfully!"
}

# Get Terraform outputs
get_terraform_outputs() {
    print_status "Getting Terraform outputs..."
    cd terraform
    
    echo ""
    echo "=== Infrastructure Details ==="
    echo "Cluster Name: $(terraform output -raw cluster_name)"
    echo "Cluster Endpoint: $(terraform output -raw cluster_endpoint)"
    echo "Region: $(terraform output -raw region)"
    echo ""
    echo "ECR Repositories:"
    terraform output -json ecr_repositories | jq -r 'to_entries[] | "  \(.key): \(.value)"'
    echo ""
    
    cd ..
}

# Configure kubectl
configure_kubectl() {
    print_status "Configuring kubectl for EKS cluster..."
    aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
    
    # Verify connection
    if kubectl cluster-info &> /dev/null; then
        print_status "Successfully connected to EKS cluster!"
        
        echo ""
        echo "=== Cluster Information ==="
        kubectl cluster-info
        echo ""
        echo "=== Node Status ==="
        kubectl get nodes
        echo ""
    else
        print_error "Failed to connect to EKS cluster. Please check your configuration."
        exit 1
    fi
}

# Display next steps
display_next_steps() {
    print_header "Next Steps"
    echo ""
    echo "Infrastructure setup completed successfully!"
    echo ""
    echo "To deploy the OpenTelemetry demo applications:"
    echo "  1. Build and push Docker images:"
    echo "     ./scripts/build-and-push.sh"
    echo ""
    echo "  2. Deploy the observability stack:"
    echo "     ./scripts/deploy-observability.sh"
    echo ""
    echo "  3. Deploy the applications:"
    echo "     ./scripts/deploy-to-eks.sh"
    echo ""
    echo "To destroy the infrastructure when done:"
    echo "     cd terraform && terraform destroy"
    echo ""
    print_warning "Remember to destroy resources when not in use to avoid charges!"
}

# Main execution
main() {
    print_header "OpenTelemetry EKS Demo - Infrastructure Setup"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Show cost estimation
    estimate_costs
    
    # Initialize Terraform
    init_terraform
    
    # Plan deployment
    plan_terraform
    
    # Apply Terraform configuration
    apply_terraform
    
    # Get outputs
    get_terraform_outputs
    
    # Configure kubectl
    configure_kubectl
    
    # Display next steps
    display_next_steps
}

# Run main function
main "$@"

