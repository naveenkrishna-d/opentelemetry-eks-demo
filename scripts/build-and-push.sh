#!/bin/bash

# Build and Push Docker Images to ECR
# This script builds all microservice images and pushes them to ECR

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
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    # Check if AWS credentials are configured
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_status "Prerequisites check passed!"
}

# Login to ECR
ecr_login() {
    print_status "Logging in to ECR..."
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
}

# Build and push a single service
build_and_push_service() {
    local service_name=$1
    local dockerfile_path=$2
    
    print_status "Building and pushing $service_name..."
    
    # ECR repository URL
    local ecr_repo="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$CLUSTER_NAME-$service_name"
    
    # Build the Docker image
    print_status "Building Docker image for $service_name..."
    docker build -t $service_name:latest $dockerfile_path
    
    # Tag the image for ECR
    docker tag $service_name:latest $ecr_repo:latest
    docker tag $service_name:latest $ecr_repo:v1.0.0
    
    # Push the image to ECR
    print_status "Pushing $service_name to ECR..."
    docker push $ecr_repo:latest
    docker push $ecr_repo:v1.0.0
    
    print_status "$service_name pushed successfully!"
}

# Main execution
main() {
    print_status "Starting build and push process..."
    
    # Check prerequisites
    check_prerequisites
    
    # Login to ECR
    ecr_login
    
    # Build and push each service
    print_status "Building and pushing microservices..."
    
    # Product Catalog Service
    build_and_push_service "productcatalog" "./src/productcatalog"
    
    # Cart Service
    build_and_push_service "cart" "./src/cart"
    
    # Frontend Service
    build_and_push_service "frontend" "./src/frontend"
    
    print_status "All services built and pushed successfully!"
    print_status "You can now deploy the applications to EKS using the deploy script."
}

# Run main function
main "$@"

