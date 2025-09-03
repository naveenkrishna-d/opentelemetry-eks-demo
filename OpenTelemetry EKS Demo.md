# OpenTelemetry on AWS EKS Demo

A comprehensive demonstration of OpenTelemetry distributed tracing and observability on Amazon Elastic Kubernetes Service (EKS). This project showcases how to instrument microservices applications with OpenTelemetry, collect telemetry data using the OpenTelemetry Collector, and visualize the data using Jaeger, Prometheus, and Grafana.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Cost Considerations](#cost-considerations)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Application Services](#application-services)
- [Observability Stack](#observability-stack)
- [Usage and Testing](#usage-and-testing)
- [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
- [Cleanup](#cleanup)
- [Contributing](#contributing)
- [License](#license)

## Overview

This project demonstrates a complete OpenTelemetry implementation on AWS EKS, featuring:

- **Microservices Architecture**: Three interconnected services (Frontend, Product Catalog, Cart) written in different programming languages
- **OpenTelemetry Instrumentation**: Comprehensive tracing and metrics collection across all services
- **Distributed Tracing**: End-to-end request tracing using Jaeger
- **Metrics Collection**: Application and infrastructure metrics using Prometheus
- **Visualization**: Rich dashboards and alerting using Grafana
- **Cloud-Native Deployment**: Kubernetes-native deployment on AWS EKS
- **Cost-Optimized**: Designed to work within AWS free tier constraints

The demo application simulates an e-commerce platform where users can browse products, add items to their cart, and complete purchases. Each user interaction generates traces and metrics that flow through the OpenTelemetry Collector to the observability backend.




## Architecture

The OpenTelemetry EKS demo follows a modern microservices architecture with comprehensive observability instrumentation. The system is designed to demonstrate real-world distributed tracing scenarios while maintaining simplicity for educational purposes.

### System Components

#### Application Layer
The application consists of three core microservices, each implemented in a different programming language to showcase OpenTelemetry's cross-language compatibility:

**Frontend Service (Node.js/Express)**
- Serves the web user interface and handles user interactions
- Orchestrates calls to downstream services
- Implements OpenTelemetry automatic instrumentation for HTTP requests
- Generates custom metrics for user engagement tracking
- Exposes REST API endpoints for the web application

**Product Catalog Service (Python/Flask)**
- Manages product information and inventory
- Provides product search and retrieval capabilities
- Implements both automatic and manual OpenTelemetry instrumentation
- Simulates database operations with configurable latency
- Generates business metrics for product access patterns

**Cart Service (Go/Gin)**
- Handles shopping cart operations and state management
- Communicates with Product Catalog for product validation
- Demonstrates Go-specific OpenTelemetry instrumentation patterns
- Implements in-memory storage with metrics tracking
- Provides cart lifecycle management (add, view, empty)

#### Observability Infrastructure

**OpenTelemetry Collector**
The OpenTelemetry Collector serves as the central telemetry data processing hub, configured with multiple receivers, processors, and exporters:

- **Receivers**: OTLP (gRPC and HTTP), Kubernetes cluster metrics, Kubelet stats
- **Processors**: Batch processing, memory limiting, resource attribution, Kubernetes metadata enrichment
- **Exporters**: Jaeger (traces), Prometheus (metrics), logging (debugging)

The Collector is deployed as a Kubernetes Deployment with appropriate RBAC permissions to access cluster metadata and node statistics.

**Jaeger (Distributed Tracing)**
Jaeger provides distributed tracing capabilities with the following configuration:
- All-in-one deployment suitable for demo environments
- In-memory storage for simplicity (production would use persistent storage)
- OTLP receiver enabled for OpenTelemetry compatibility
- Web UI accessible via LoadBalancer for trace visualization

**Prometheus (Metrics Collection)**
Prometheus collects and stores time-series metrics data:
- Scrapes metrics from the OpenTelemetry Collector
- Discovers Kubernetes pods with Prometheus annotations
- Configured with appropriate retention policies for cost optimization
- Provides PromQL query interface for metric analysis

**Grafana (Visualization and Dashboards)**
Grafana serves as the primary visualization platform:
- Pre-configured data sources for Prometheus and Jaeger
- Custom dashboards for application and infrastructure monitoring
- Default admin credentials for demo access
- Extensible dashboard configuration for additional metrics

### Data Flow Architecture

The telemetry data flows through the system following OpenTelemetry best practices:

1. **Instrumentation**: Each microservice generates traces and metrics using OpenTelemetry SDKs
2. **Collection**: The OpenTelemetry Collector receives telemetry data via OTLP protocol
3. **Processing**: Collected data is enriched with Kubernetes metadata and batched for efficiency
4. **Export**: Processed data is exported to appropriate backends (Jaeger for traces, Prometheus for metrics)
5. **Visualization**: End users access traces via Jaeger UI and metrics via Grafana dashboards

### Network Architecture

The system is deployed within a custom VPC with the following network configuration:

- **VPC**: 10.0.0.0/16 CIDR block with DNS resolution enabled
- **Public Subnets**: Two subnets across different AZs for high availability
- **Private Subnets**: Two subnets for EKS worker nodes and application pods
- **NAT Gateway**: Single NAT gateway for cost optimization (production would use multiple)
- **Internet Gateway**: Provides internet access for public subnets
- **Security Groups**: Configured for minimal required access between components

### Kubernetes Architecture

The application is deployed using Kubernetes best practices:

- **Namespaces**: All components deployed in the default namespace for simplicity
- **Deployments**: Each service deployed as a Kubernetes Deployment with health checks
- **Services**: ClusterIP services for internal communication, LoadBalancer for external access
- **ConfigMaps**: Configuration management for OpenTelemetry Collector and observability tools
- **RBAC**: Appropriate service accounts and permissions for cluster access
- **Resource Limits**: CPU and memory limits configured for cost optimization

This architecture provides a realistic demonstration of OpenTelemetry in a cloud-native environment while maintaining cost efficiency and educational clarity.


## Prerequisites

Before deploying the OpenTelemetry EKS demo, ensure you have the following tools and accounts configured:

### Required Tools

**AWS CLI (version 2.x recommended)**
The AWS Command Line Interface is required for interacting with AWS services and configuring EKS access.
```bash
# Install AWS CLI v2 on Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
```

**Terraform (version 1.0+)**
Terraform is used for infrastructure as code to provision the EKS cluster and supporting AWS resources.
```bash
# Install Terraform on Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify installation
terraform version
```

**kubectl (compatible with Kubernetes 1.28)**
The Kubernetes command-line tool is required for interacting with the EKS cluster.
```bash
# Install kubectl on Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Verify installation
kubectl version --client
```

**Docker (version 20.x+)**
Docker is required for building and testing container images locally.
```bash
# Install Docker on Ubuntu/Debian
sudo apt-get update
sudo apt-get install docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

# Verify installation
docker --version
```

### AWS Account Setup

**AWS Account with Free Tier**
You'll need an AWS account with at least $100 in credits or budget allocation. The free tier provides some resources, but this demo will exceed free tier limits.

**AWS Credentials Configuration**
Configure your AWS credentials using one of the following methods:
```bash
# Method 1: AWS CLI configuration
aws configure

# Method 2: Environment variables
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_DEFAULT_REGION=us-west-2
```

**Required AWS Permissions**
Your AWS user or role must have permissions for:
- EC2 (VPC, subnets, security groups, instances)
- EKS (cluster creation and management)
- IAM (role and policy creation)
- ECR (container registry operations)
- CloudWatch (logging and monitoring)

### Local Development Environment

**Git**
Required for cloning the repository and version control.
```bash
# Install Git on Ubuntu/Debian
sudo apt-get install git

# Verify installation
git --version
```

**Text Editor or IDE**
Any text editor capable of handling YAML, JSON, and code files. Recommended options include:
- Visual Studio Code with Kubernetes and Terraform extensions
- Vim with syntax highlighting
- Nano for simple edits

## Cost Considerations

Understanding the cost implications is crucial before deploying this demo, especially when working with a limited budget or free tier credits.

### Estimated Monthly Costs (US-West-2)

The following cost breakdown assumes continuous operation for a full month:

| Service | Configuration | Estimated Monthly Cost |
|---------|---------------|----------------------|
| EKS Cluster | Control plane | $73.00 |
| EC2 Instances | 2x t3.small (on-demand) | $30.00 |
| NAT Gateway | Single gateway | $32.00 |
| EBS Storage | 20GB gp3 per node | $2.00 |
| Data Transfer | Moderate usage | $5.00 |
| ECR Storage | Container images | $1.00 |
| CloudWatch Logs | EKS logging | $3.00 |
| **Total** | | **~$146.00** |

### Cost Optimization Strategies

**Time-Based Usage**
The most effective cost reduction strategy is limiting runtime:
- Deploy for testing/demo sessions only
- Destroy infrastructure when not in use
- Use automation scripts for quick setup/teardown

**Instance Type Optimization**
Consider these alternatives for reduced costs:
- Use t3.micro instances (may have performance limitations)
- Implement cluster autoscaling to scale down during low usage
- Use Spot instances for non-critical workloads (requires additional configuration)

**Resource Right-Sizing**
Optimize resource allocation:
- Reduce replica counts for demo purposes
- Lower CPU and memory requests/limits
- Use smaller EBS volumes
- Disable unnecessary logging

**Regional Considerations**
Some AWS regions have lower costs:
- Consider us-east-1 for potentially lower costs
- Be aware of data transfer costs between regions
- Factor in latency requirements for your location

### Free Tier Limitations

AWS Free Tier provides limited resources that won't cover this demo:
- 750 hours of t2.micro EC2 instances (insufficient for EKS nodes)
- No free tier for EKS control plane
- Limited data transfer allowances
- No free tier for NAT Gateway

### Budget Monitoring

Set up AWS budget alerts to monitor spending:
```bash
# Create a budget alert via AWS CLI
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://budget-config.json
```

### Recommended Usage Pattern

For optimal cost management:
1. **Setup Phase**: Deploy infrastructure and test functionality (2-3 hours)
2. **Demo Phase**: Run demonstrations and explore features (1-2 hours)
3. **Learning Phase**: Experiment with configurations and monitoring (2-4 hours)
4. **Cleanup Phase**: Destroy all resources immediately after use

**Total Recommended Runtime**: 6-10 hours maximum
**Estimated Cost for Short-Term Usage**: $5-15

This approach allows you to experience the full functionality while staying within reasonable budget constraints.


## Quick Start

For users who want to get the demo running quickly, follow these condensed steps:

### 1. Clone and Setup
```bash
git clone <repository-url>
cd opentelemetry-eks-demo
```

### 2. Configure AWS
```bash
aws configure
# Enter your AWS credentials and set region to us-west-2
```

### 3. Deploy Infrastructure
```bash
./scripts/setup-infrastructure.sh
```

### 4. Build and Deploy Applications
```bash
./scripts/build-and-push.sh
./scripts/deploy-observability.sh
./scripts/deploy-to-eks.sh
```

### 5. Access the Demo
- Frontend: Check LoadBalancer URL from kubectl output
- Jaeger: `kubectl port-forward service/jaeger-ui 16686:16686`
- Grafana: `kubectl port-forward service/grafana 3000:3000` (admin/admin123)
- Prometheus: `kubectl port-forward service/prometheus 9090:9090`

### 6. Cleanup (Important!)
```bash
cd terraform
terraform destroy
```

## Detailed Setup

This section provides comprehensive step-by-step instructions for deploying the OpenTelemetry EKS demo.

### Step 1: Repository Setup

Begin by cloning the repository and examining the project structure:

```bash
git clone <repository-url>
cd opentelemetry-eks-demo
```

The project structure is organized as follows:
```
opentelemetry-eks-demo/
├── src/                          # Application source code
│   ├── frontend/                 # Node.js frontend service
│   ├── productcatalog/          # Python product catalog service
│   └── cart/                    # Go cart service
├── k8s/                         # Kubernetes manifests
│   ├── apps/                    # Application deployments
│   ├── otel-collector/          # OpenTelemetry Collector configuration
│   └── observability/           # Jaeger, Prometheus, Grafana
├── terraform/                   # Infrastructure as code
├── scripts/                     # Deployment automation scripts
└── docs/                        # Additional documentation
```

### Step 2: AWS Configuration

Configure your AWS credentials and verify access:

```bash
# Configure AWS CLI
aws configure
# AWS Access Key ID: [Enter your access key]
# AWS Secret Access Key: [Enter your secret key]
# Default region name: us-west-2
# Default output format: json

# Verify configuration
aws sts get-caller-identity
aws eks list-clusters --region us-west-2
```

Ensure your AWS user has the necessary permissions by testing key operations:
```bash
# Test EC2 permissions
aws ec2 describe-vpcs --region us-west-2

# Test IAM permissions
aws iam list-roles --max-items 1

# Test ECR permissions
aws ecr describe-repositories --region us-west-2 || echo "No repositories found (expected)"
```

### Step 3: Infrastructure Provisioning

The infrastructure setup script automates the entire AWS resource provisioning process using Terraform:

```bash
./scripts/setup-infrastructure.sh
```

This script performs the following operations:

**Prerequisites Check**
- Verifies all required tools are installed
- Confirms AWS credentials are configured
- Tests basic AWS API access

**Cost Estimation Display**
- Shows estimated monthly costs for all resources
- Provides cost optimization recommendations
- Warns about free tier limitations

**Terraform Operations**
- Initializes Terraform with required providers
- Plans the infrastructure deployment
- Applies the configuration after user confirmation
- Outputs important resource information

**EKS Configuration**
- Updates kubectl configuration for the new cluster
- Verifies cluster connectivity
- Displays cluster and node information

The infrastructure includes:
- Custom VPC with public and private subnets
- EKS cluster with managed node group
- Security groups with minimal required access
- ECR repositories for container images
- IAM roles and policies for EKS operations

### Step 4: Container Image Management

Build and push the application container images to ECR:

```bash
./scripts/build-and-push.sh
```

This script handles:

**Docker Image Building**
- Builds images for all three microservices
- Uses multi-stage builds for optimization
- Applies consistent tagging strategy

**ECR Authentication**
- Authenticates Docker with ECR
- Handles region-specific ECR endpoints

**Image Publishing**
- Pushes images with both 'latest' and version tags
- Provides progress feedback for each service
- Verifies successful uploads

You can verify the images were pushed successfully:
```bash
aws ecr list-images --repository-name otel-demo-cluster-frontend --region us-west-2
aws ecr list-images --repository-name otel-demo-cluster-productcatalog --region us-west-2
aws ecr list-images --repository-name otel-demo-cluster-cart --region us-west-2
```

### Step 5: Observability Stack Deployment

Deploy the observability infrastructure before the applications:

```bash
./scripts/deploy-observability.sh
```

This deployment includes:

**Jaeger Configuration**
- All-in-one deployment with OTLP receivers
- In-memory storage for demo purposes
- LoadBalancer service for external access
- Health checks and resource limits

**Prometheus Setup**
- Service discovery for Kubernetes pods
- OpenTelemetry Collector metrics scraping
- Retention policies for cost optimization
- RBAC configuration for cluster access

**Grafana Installation**
- Pre-configured data sources
- Default dashboards for OpenTelemetry metrics
- Admin user with demo credentials
- Persistent volume for dashboard storage

Monitor the deployment progress:
```bash
kubectl get pods -w
kubectl get services
```

### Step 6: Application Deployment

Deploy the instrumented microservices:

```bash
./scripts/deploy-to-eks.sh
```

The deployment process:

**Image Reference Updates**
- Updates Kubernetes manifests with ECR image URLs
- Applies environment-specific configurations
- Sets OpenTelemetry endpoint configurations

**Application Rollout**
- Deploys OpenTelemetry Collector first
- Deploys backend services (Product Catalog, Cart)
- Deploys frontend service last
- Waits for all deployments to become ready

**Service Exposure**
- Creates LoadBalancer for frontend access
- Configures internal ClusterIP services
- Sets up health check endpoints

Verify the deployment:
```bash
kubectl get deployments
kubectl get pods
kubectl get services
kubectl logs deployment/otel-collector
```

### Step 7: Access and Verification

Once all components are deployed, access the various interfaces:

**Frontend Application**
```bash
# Get LoadBalancer URL
kubectl get service frontend
# Access via browser: http://<EXTERNAL-IP>:8080
```

**Jaeger Tracing UI**
```bash
# Port forward if LoadBalancer is not ready
kubectl port-forward service/jaeger-ui 16686:16686
# Access via browser: http://localhost:16686
```

**Grafana Dashboards**
```bash
# Port forward if LoadBalancer is not ready
kubectl port-forward service/grafana 3000:3000
# Access via browser: http://localhost:3000
# Login: admin / admin123
```

**Prometheus Metrics**
```bash
# Port forward if LoadBalancer is not ready
kubectl port-forward service/prometheus 9090:9090
# Access via browser: http://localhost:9090
```

This completes the full deployment process. The next sections cover usage, monitoring, and troubleshooting.


## Application Services

The demo application consists of three microservices that work together to simulate an e-commerce platform. Each service demonstrates different aspects of OpenTelemetry instrumentation and distributed tracing.

### Frontend Service (Node.js/Express)

The frontend service serves as the user-facing component and orchestrates interactions with backend services.

**Technology Stack**
- Node.js 18+ with Express framework
- OpenTelemetry Node.js SDK with automatic instrumentation
- Axios for HTTP client requests with tracing
- CORS enabled for cross-origin requests

**Key Features**
- Single-page web application with product browsing
- Shopping cart management interface
- User session handling with configurable user IDs
- Comprehensive error handling and logging

**OpenTelemetry Instrumentation**
The frontend service implements both automatic and manual instrumentation:

```javascript
// Automatic instrumentation for HTTP requests
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');

// Manual span creation for business logic
const span = tracer.startSpan('process_user_request');
span.setAttributes({
  'user.id': userId,
  'request.type': 'product_search'
});
```

**Metrics Generated**
- `frontend_requests_total`: Counter for total HTTP requests
- `frontend_request_duration_seconds`: Histogram for request latency
- `frontend_active_users`: Gauge for concurrent user sessions

**API Endpoints**
- `GET /`: Serves the main application interface
- `GET /health`: Health check endpoint
- `GET /api/products`: Proxies product catalog requests
- `POST /api/cart/:userId/items`: Adds items to user cart
- `GET /api/cart/:userId`: Retrieves user cart contents
- `DELETE /api/cart/:userId`: Empties user cart

### Product Catalog Service (Python/Flask)

The product catalog service manages product information and provides search capabilities.

**Technology Stack**
- Python 3.11 with Flask web framework
- OpenTelemetry Python SDK with Flask instrumentation
- CORS support for cross-origin requests
- Structured logging with correlation IDs

**Key Features**
- Product inventory management with sample data
- Search functionality with text matching
- Configurable response latency simulation
- Comprehensive product metadata

**OpenTelemetry Instrumentation**
The service uses both automatic Flask instrumentation and manual span creation:

```python
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry import trace

# Automatic instrumentation
FlaskInstrumentor().instrument_app(app)

# Manual span creation
with tracer.start_as_current_span("search_products") as span:
    span.set_attribute("search.query", query)
    span.set_attribute("search.results_count", len(results))
```

**Sample Product Data**
The service includes a curated set of sample products:
- Vintage Typewriter ($67.99)
- Vintage Camera Lens ($12.49)
- Home Barista Kit ($124.00)
- Terrarium ($36.45)
- Film Camera ($2,245.00)

**Metrics Generated**
- `product_requests_total`: Counter for API requests by endpoint
- `product_request_duration_seconds`: Histogram for response times
- `product_search_queries_total`: Counter for search operations
- `product_inventory_size`: Gauge for total product count

### Cart Service (Go/Gin)

The cart service handles shopping cart operations and demonstrates Go-specific OpenTelemetry patterns.

**Technology Stack**
- Go 1.21 with Gin web framework
- OpenTelemetry Go SDK with Gin instrumentation
- In-memory storage with concurrent access handling
- Structured logging with trace correlation

**Key Features**
- Thread-safe cart operations using mutexes
- Product validation via Product Catalog service
- User session management
- Automatic cart cleanup capabilities

**OpenTelemetry Instrumentation**
The Go service demonstrates comprehensive instrumentation patterns:

```go
import (
    "go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
    "go.opentelemetry.io/otel"
)

// Automatic middleware
r.Use(otelgin.Middleware("cart"))

// Manual span creation
ctx, span := tracer.Start(ctx, "validate_product")
defer span.End()
span.SetAttributes(attribute.String("product.id", productID))
```

**Data Structures**
```go
type Cart struct {
    UserID string     `json:"user_id"`
    Items  []CartItem `json:"items"`
    mutex  sync.RWMutex
}

type CartItem struct {
    ProductID string `json:"product_id"`
    Quantity  int    `json:"quantity"`
}
```

**Metrics Generated**
- `cart_requests_total`: Counter for cart operations
- `cart_request_duration_seconds`: Histogram for operation latency
- `cart_items_total`: UpDownCounter for total items across all carts
- `cart_operations_total`: Counter by operation type (add, remove, view)

## Observability Stack

The observability stack provides comprehensive monitoring, tracing, and alerting capabilities for the microservices application.

### OpenTelemetry Collector

The OpenTelemetry Collector serves as the central telemetry processing hub, implementing the vendor-neutral OpenTelemetry protocol.

**Configuration Architecture**
The Collector is configured with a pipeline approach:

```yaml
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, k8sattributes, resource, batch]
      exporters: [jaeger, otlp/jaeger, logging]
    
    metrics:
      receivers: [otlp, k8s_cluster, kubeletstats]
      processors: [memory_limiter, k8sattributes, resource, batch]
      exporters: [prometheus, logging]
```

**Receivers Configuration**
- **OTLP Receiver**: Accepts telemetry data from instrumented applications
- **Kubernetes Cluster Receiver**: Collects cluster-level metrics
- **Kubelet Stats Receiver**: Gathers node and pod metrics

**Processors Configuration**
- **Batch Processor**: Optimizes export efficiency by batching telemetry data
- **Memory Limiter**: Prevents out-of-memory conditions
- **Resource Processor**: Adds cluster and environment metadata
- **K8s Attributes Processor**: Enriches data with Kubernetes metadata

**Exporters Configuration**
- **Jaeger Exporter**: Sends traces to Jaeger for distributed tracing
- **Prometheus Exporter**: Exposes metrics in Prometheus format
- **Logging Exporter**: Provides debugging output for troubleshooting

### Jaeger Distributed Tracing

Jaeger provides distributed tracing capabilities with comprehensive trace visualization and analysis.

**Deployment Configuration**
The Jaeger all-in-one deployment includes:
- Jaeger Agent for trace collection
- Jaeger Collector for trace processing
- Jaeger Query for trace retrieval
- Jaeger UI for trace visualization
- In-memory storage for demo purposes

**Trace Analysis Features**
- **Service Map**: Visual representation of service dependencies
- **Trace Timeline**: Detailed view of request flow through services
- **Span Details**: Individual operation analysis with tags and logs
- **Error Analysis**: Identification of failed operations and error patterns
- **Performance Analysis**: Latency distribution and bottleneck identification

**Sample Trace Flow**
A typical user interaction generates the following trace:
1. Frontend receives HTTP request
2. Frontend calls Product Catalog service
3. Product Catalog processes search query
4. Frontend calls Cart service
5. Cart service validates product with Product Catalog
6. Cart service updates cart state
7. Frontend returns response to user

### Prometheus Metrics Collection

Prometheus provides time-series metrics collection and storage with powerful querying capabilities.

**Metrics Collection Strategy**
- **Pull-based Model**: Prometheus scrapes metrics from configured targets
- **Service Discovery**: Automatic discovery of Kubernetes pods and services
- **Label-based Data Model**: Rich metadata for metric filtering and aggregation

**Key Metric Types**
- **Counters**: Monotonically increasing values (request counts, error counts)
- **Gauges**: Point-in-time values (active connections, queue sizes)
- **Histograms**: Distribution of values (request latencies, response sizes)
- **Summaries**: Similar to histograms with client-side quantile calculation

**Sample Queries**
```promql
# Request rate per service
sum(rate(otel_frontend_requests_total[5m])) by (service)

# 95th percentile response time
histogram_quantile(0.95, sum(rate(otel_request_duration_seconds_bucket[5m])) by (le))

# Error rate
sum(rate(otel_requests_total{status="error"}[5m])) / sum(rate(otel_requests_total[5m]))
```

### Grafana Visualization

Grafana provides rich visualization and dashboarding capabilities for metrics and traces.

**Data Source Configuration**
- **Prometheus**: Primary metrics data source
- **Jaeger**: Distributed tracing data source
- **CloudWatch**: AWS infrastructure metrics (optional)

**Pre-configured Dashboards**
- **Application Overview**: High-level service health and performance
- **Service Details**: Individual service metrics and traces
- **Infrastructure Monitoring**: Kubernetes cluster and node metrics
- **Error Analysis**: Error rates and failure patterns

**Alerting Capabilities**
- **Threshold Alerts**: Based on metric values and trends
- **Anomaly Detection**: Statistical analysis of metric patterns
- **Multi-condition Alerts**: Complex alerting logic with multiple criteria
- **Notification Channels**: Email, Slack, PagerDuty integration

**Custom Dashboard Creation**
Users can create custom dashboards using:
- PromQL queries for Prometheus metrics
- Jaeger trace queries for distributed tracing
- Template variables for dynamic filtering
- Panel types including graphs, tables, and heatmaps


## Usage and Testing

This section provides comprehensive guidance on using the OpenTelemetry EKS demo to explore distributed tracing and observability features.

### Accessing the Application

Once deployed, the application can be accessed through multiple interfaces:

**Web Application Interface**
The frontend service provides a user-friendly web interface for interacting with the e-commerce demo:

```bash
# Get the LoadBalancer URL
kubectl get service frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# If LoadBalancer is not available, use port forwarding
kubectl port-forward service/frontend 8080:8080
```

Navigate to the application URL and explore the following features:
- Browse the product catalog with sample items
- Add products to your shopping cart
- View cart contents and manage items
- Switch between different user IDs to simulate multiple users
- Observe real-time updates and error handling

**Observability Interfaces**
Access the observability stack through the following endpoints:

```bash
# Jaeger UI for distributed tracing
kubectl port-forward service/jaeger-ui 16686:16686
# Access: http://localhost:16686

# Grafana for metrics visualization
kubectl port-forward service/grafana 3000:3000
# Access: http://localhost:3000 (admin/admin123)

# Prometheus for metrics queries
kubectl port-forward service/prometheus 9090:9090
# Access: http://localhost:9090
```

### Generating Test Traffic

To demonstrate the observability features effectively, generate various types of traffic patterns:

**Basic User Interactions**
Simulate normal user behavior:
```bash
# Script to generate basic traffic
for i in {1..10}; do
  curl -X GET "http://<frontend-url>:8080/api/products"
  curl -X POST "http://<frontend-url>:8080/api/cart/user$i/items" \
    -H "Content-Type: application/json" \
    -d '{"product_id":"OLJCESPC7Z","quantity":1}'
  sleep 2
done
```

**Load Testing**
Generate sustained load to observe performance characteristics:
```bash
# Install Apache Bench for load testing
sudo apt-get install apache2-utils

# Generate load on the frontend
ab -n 1000 -c 10 http://<frontend-url>:8080/api/products

# Generate load on specific endpoints
ab -n 500 -c 5 -p cart-data.json -T application/json \
  http://<frontend-url>:8080/api/cart/loadtest/items
```

**Error Simulation**
Test error handling and observability:
```bash
# Request non-existent products
curl "http://<frontend-url>:8080/api/products/INVALID_ID"

# Send malformed requests
curl -X POST "http://<frontend-url>:8080/api/cart/user1/items" \
  -H "Content-Type: application/json" \
  -d '{"invalid":"data"}'

# Simulate network timeouts
curl --max-time 1 "http://<frontend-url>:8080/api/products"
```

### Exploring Distributed Traces

Use Jaeger to analyze distributed traces and understand request flows:

**Trace Analysis Workflow**
1. **Service Selection**: Choose a service from the dropdown (frontend, productcatalog, cart)
2. **Time Range**: Set appropriate time range for trace collection
3. **Trace Search**: Use tags and filters to find specific traces
4. **Trace Inspection**: Click on traces to view detailed span information

**Key Trace Patterns to Observe**
- **Successful Request Flow**: Complete trace from frontend through all services
- **Error Propagation**: How errors in downstream services affect upstream services
- **Performance Bottlenecks**: Identify slow operations and their impact
- **Service Dependencies**: Understand the relationship between services

**Sample Trace Analysis**
Look for traces with the following characteristics:
```
Frontend Service (span: http_request)
├── Product Catalog Call (span: get_products)
│   ├── Database Query Simulation (span: search_products)
│   └── Response Processing (span: format_response)
└── Cart Service Call (span: add_to_cart)
    ├── Product Validation (span: validate_product)
    │   └── Product Catalog Call (span: get_product)
    └── Cart Update (span: update_cart_state)
```

### Metrics Analysis with Prometheus

Explore application and infrastructure metrics using Prometheus queries:

**Application Metrics Queries**
```promql
# Request rate by service
sum(rate(otel_requests_total[5m])) by (service_name)

# Error rate percentage
(sum(rate(otel_requests_total{status_code!~"2.."}[5m])) / 
 sum(rate(otel_requests_total[5m]))) * 100

# Response time percentiles
histogram_quantile(0.95, 
  sum(rate(otel_request_duration_seconds_bucket[5m])) by (le, service_name))

# Active cart items
sum(otel_cart_items_total)
```

**Infrastructure Metrics Queries**
```promql
# CPU usage by pod
sum(rate(container_cpu_usage_seconds_total[5m])) by (pod)

# Memory usage by service
sum(container_memory_working_set_bytes) by (service)

# Network traffic
sum(rate(container_network_receive_bytes_total[5m])) by (pod)
```

### Dashboard Exploration in Grafana

Navigate through the pre-configured dashboards to understand different aspects of the system:

**Application Overview Dashboard**
- Service health indicators and uptime
- Request rates and response times across all services
- Error rates and success percentages
- Top endpoints by traffic volume

**Service-Specific Dashboards**
- Individual service performance metrics
- Service dependency visualization
- Custom business metrics (cart operations, product searches)
- Resource utilization per service

**Infrastructure Dashboard**
- Kubernetes cluster health
- Node resource utilization
- Pod lifecycle and restart patterns
- Network and storage metrics

### Creating Custom Dashboards

Build custom dashboards to monitor specific aspects of your application:

**Dashboard Creation Process**
1. Navigate to Grafana and click "Create Dashboard"
2. Add panels with relevant Prometheus queries
3. Configure visualization types (time series, stat, gauge, table)
4. Set up template variables for dynamic filtering
5. Configure alerting rules for critical metrics

**Sample Custom Panel Configuration**
```json
{
  "title": "Cart Operations by User",
  "type": "timeseries",
  "targets": [
    {
      "expr": "sum(rate(otel_cart_requests_total[5m])) by (user_id)",
      "legendFormat": "User {{user_id}}"
    }
  ]
}
```

## Monitoring and Troubleshooting

Effective monitoring and troubleshooting are essential for maintaining the health and performance of the OpenTelemetry demo environment.

### Health Monitoring

Monitor the overall health of the system using multiple approaches:

**Kubernetes Health Checks**
```bash
# Check pod status
kubectl get pods -o wide

# Check deployment status
kubectl get deployments

# Check service endpoints
kubectl get endpoints

# View recent events
kubectl get events --sort-by=.metadata.creationTimestamp
```

**Application Health Endpoints**
Each service provides health check endpoints:
```bash
# Frontend health
curl http://<frontend-url>:8080/health

# Product Catalog health
kubectl port-forward service/productcatalog 7000:7000
curl http://localhost:7000/health

# Cart service health
kubectl port-forward service/cart 7001:7001
curl http://localhost:7001/health
```

**OpenTelemetry Collector Health**
```bash
# Check collector health endpoint
kubectl port-forward service/otel-collector 13133:13133
curl http://localhost:13133/

# View collector metrics
curl http://localhost:13133/metrics
```

### Log Analysis

Analyze logs from various components to identify issues:

**Application Logs**
```bash
# Frontend service logs
kubectl logs deployment/frontend -f

# Product catalog logs
kubectl logs deployment/productcatalog -f

# Cart service logs
kubectl logs deployment/cart -f

# OpenTelemetry Collector logs
kubectl logs deployment/otel-collector -f
```

**Structured Log Analysis**
Look for key patterns in the logs:
- Request correlation IDs for tracing requests across services
- Error messages with stack traces
- Performance warnings and timeouts
- OpenTelemetry instrumentation status messages

### Common Issues and Solutions

**Issue: Pods Not Starting**
```bash
# Check pod status and events
kubectl describe pod <pod-name>

# Common causes and solutions:
# - Image pull errors: Verify ECR permissions and image tags
# - Resource constraints: Check node capacity and resource requests
# - Configuration errors: Validate ConfigMaps and environment variables
```

**Issue: Services Not Communicating**
```bash
# Test service connectivity
kubectl exec -it <frontend-pod> -- curl http://productcatalog:7000/health

# Check service discovery
kubectl get services
kubectl get endpoints

# Verify network policies and security groups
```

**Issue: No Traces in Jaeger**
```bash
# Verify OpenTelemetry Collector is receiving data
kubectl logs deployment/otel-collector | grep -i "trace"

# Check application instrumentation
kubectl logs deployment/frontend | grep -i "opentelemetry"

# Verify Jaeger connectivity
kubectl port-forward service/jaeger-ui 16686:16686
# Check Jaeger UI for service list
```

**Issue: Missing Metrics in Prometheus**
```bash
# Check Prometheus targets
kubectl port-forward service/prometheus 9090:9090
# Navigate to Status > Targets in Prometheus UI

# Verify OpenTelemetry Collector metrics endpoint
kubectl port-forward service/otel-collector 8889:8889
curl http://localhost:8889/metrics

# Check Prometheus configuration
kubectl get configmap prometheus-config -o yaml
```

### Performance Optimization

Optimize the demo environment for better performance and cost efficiency:

**Resource Optimization**
```bash
# Monitor resource usage
kubectl top pods
kubectl top nodes

# Adjust resource requests and limits
kubectl patch deployment frontend -p '{"spec":{"template":{"spec":{"containers":[{"name":"frontend","resources":{"requests":{"cpu":"50m","memory":"64Mi"}}}]}}}}'
```

**OpenTelemetry Collector Tuning**
```yaml
# Optimize collector configuration
processors:
  batch:
    timeout: 1s
    send_batch_size: 1024
  memory_limiter:
    limit_mib: 256
    spike_limit_mib: 64
```

**Observability Stack Optimization**
- Reduce Prometheus retention period for cost savings
- Optimize Grafana dashboard refresh rates
- Configure appropriate log levels for production use

### Debugging Techniques

Advanced debugging techniques for complex issues:

**Distributed Tracing Debugging**
1. Enable debug logging in OpenTelemetry SDKs
2. Use trace sampling to reduce overhead
3. Correlate traces with application logs
4. Analyze span relationships and timing

**Network Debugging**
```bash
# Test network connectivity between pods
kubectl exec -it <pod-name> -- nslookup <service-name>
kubectl exec -it <pod-name> -- telnet <service-name> <port>

# Analyze network policies
kubectl get networkpolicies
kubectl describe networkpolicy <policy-name>
```

**Configuration Debugging**
```bash
# Validate Kubernetes manifests
kubectl apply --dry-run=client -f k8s/deploy-apps.yaml

# Check environment variables
kubectl exec -it <pod-name> -- env | grep OTEL

# Verify ConfigMap contents
kubectl get configmap otel-collector-config -o yaml
```

This comprehensive monitoring and troubleshooting guide ensures you can effectively maintain and debug the OpenTelemetry EKS demo environment.


## Cleanup

Proper cleanup is crucial to avoid ongoing AWS charges. This section provides comprehensive instructions for removing all resources created during the demo.

### Quick Cleanup

For immediate resource removal:

```bash
# Navigate to terraform directory
cd terraform

# Destroy all AWS resources
terraform destroy -auto-approve

# Verify cleanup
aws eks list-clusters --region us-west-2
aws ec2 describe-vpcs --region us-west-2 --filters "Name=tag:Project,Values=opentelemetry-eks-demo"
```

### Detailed Cleanup Process

Follow these steps for thorough resource cleanup:

**Step 1: Application Cleanup**
```bash
# Remove Kubernetes applications
kubectl delete -f k8s/deploy-apps.yaml
kubectl delete -f k8s/observability/deploy-observability.yaml

# Verify pods are terminated
kubectl get pods
```

**Step 2: EKS Cluster Cleanup**
```bash
# Delete the EKS cluster and associated resources
cd terraform
terraform destroy

# Confirm destruction when prompted
# This will remove:
# - EKS cluster and node groups
# - VPC and networking components
# - Security groups and IAM roles
# - ECR repositories and images
# - CloudWatch log groups
```

**Step 3: Verification**
Verify that all resources have been removed:

```bash
# Check EKS clusters
aws eks list-clusters --region us-west-2

# Check EC2 instances
aws ec2 describe-instances --region us-west-2 --filters "Name=tag:Project,Values=opentelemetry-eks-demo"

# Check VPCs
aws ec2 describe-vpcs --region us-west-2 --filters "Name=tag:Project,Values=opentelemetry-eks-demo"

# Check ECR repositories
aws ecr describe-repositories --region us-west-2 | grep otel-demo

# Check IAM roles
aws iam list-roles | grep otel-demo
```

**Step 4: Manual Cleanup (if needed)**
If Terraform fails to destroy some resources, manually clean them up:

```bash
# Delete ECR repositories
aws ecr delete-repository --repository-name otel-demo-cluster-frontend --force --region us-west-2
aws ecr delete-repository --repository-name otel-demo-cluster-productcatalog --force --region us-west-2
aws ecr delete-repository --repository-name otel-demo-cluster-cart --force --region us-west-2

# Delete CloudWatch log groups
aws logs delete-log-group --log-group-name /aws/eks/otel-demo-cluster/cluster --region us-west-2

# Remove kubectl context
kubectl config delete-context arn:aws:eks:us-west-2:$(aws sts get-caller-identity --query Account --output text):cluster/otel-demo-cluster
```

### Cost Verification

After cleanup, verify that no charges are accumulating:

**AWS Cost Explorer**
1. Navigate to AWS Cost Explorer in the AWS Console
2. Set the time range to include your demo period
3. Filter by service to see EKS, EC2, and other related charges
4. Verify that no ongoing charges exist for the demo resources

**AWS Billing Dashboard**
1. Check the AWS Billing Dashboard for current month charges
2. Review the bill details for any unexpected charges
3. Set up billing alerts if not already configured

### Troubleshooting Cleanup Issues

**Issue: Terraform Destroy Fails**
```bash
# Common causes and solutions:

# 1. Dependencies still exist
terraform state list
terraform destroy -target=<specific-resource>

# 2. Resources created outside Terraform
# Manually delete via AWS Console or CLI

# 3. Permission issues
# Verify AWS credentials have deletion permissions
```

**Issue: EKS Cluster Won't Delete**
```bash
# Force delete node groups first
aws eks delete-nodegroup --cluster-name otel-demo-cluster --nodegroup-name otel-demo-cluster-nodes --region us-west-2

# Wait for node group deletion, then delete cluster
aws eks delete-cluster --name otel-demo-cluster --region us-west-2
```

**Issue: VPC Won't Delete**
```bash
# Check for remaining dependencies
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=<vpc-id>" --region us-west-2
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=<vpc-id>" --region us-west-2

# Delete dependencies manually, then retry VPC deletion
```

## Contributing

We welcome contributions to improve the OpenTelemetry EKS demo project. This section outlines how to contribute effectively.

### Development Setup

**Local Development Environment**
```bash
# Clone the repository
git clone <repository-url>
cd opentelemetry-eks-demo

# Install development dependencies
npm install -g @commitlint/cli @commitlint/config-conventional
pip install pre-commit

# Set up pre-commit hooks
pre-commit install
```

**Testing Changes**
Before submitting contributions, test your changes:

```bash
# Validate Kubernetes manifests
kubectl apply --dry-run=client -f k8s/

# Test Terraform configuration
cd terraform
terraform validate
terraform plan

# Test shell scripts
shellcheck scripts/*.sh

# Test Docker builds
docker build -t test-frontend src/frontend/
docker build -t test-productcatalog src/productcatalog/
docker build -t test-cart src/cart/
```

### Contribution Guidelines

**Code Style**
- Follow language-specific style guides (ESLint for JavaScript, Black for Python, gofmt for Go)
- Use meaningful variable and function names
- Include comprehensive comments for complex logic
- Maintain consistent indentation and formatting

**Documentation**
- Update README.md for any architectural changes
- Include inline code comments for complex configurations
- Update troubleshooting sections for new known issues
- Provide examples for new features or configurations

**Commit Messages**
Follow conventional commit format:
```
type(scope): description

feat(frontend): add user session management
fix(collector): resolve memory leak in batch processor
docs(readme): update cost estimation section
```

### Types of Contributions

**Bug Fixes**
- Report bugs using GitHub issues with detailed reproduction steps
- Include logs, error messages, and environment information
- Provide minimal test cases that demonstrate the issue

**Feature Enhancements**
- Discuss new features in GitHub issues before implementation
- Ensure new features align with the educational goals of the demo
- Include comprehensive testing and documentation

**Documentation Improvements**
- Fix typos, grammar, and formatting issues
- Add missing information or clarify existing content
- Improve code examples and troubleshooting guides

**Infrastructure Optimizations**
- Cost optimization improvements
- Performance enhancements
- Security best practices implementation

### Submission Process

**Pull Request Workflow**
1. Fork the repository and create a feature branch
2. Make your changes with appropriate tests
3. Update documentation as needed
4. Submit a pull request with a clear description
5. Address review feedback promptly

**Review Criteria**
Pull requests are evaluated based on:
- Code quality and adherence to best practices
- Comprehensive testing and validation
- Documentation completeness
- Alignment with project goals
- Backward compatibility considerations

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### MIT License Summary

The MIT License is a permissive open-source license that allows:
- Commercial and private use
- Modification and distribution
- Patent use (limited)

**Requirements:**
- Include the original license and copyright notice
- Provide attribution to the original authors

**Limitations:**
- No warranty or liability protection
- No trademark rights granted

### Third-Party Licenses

This project includes components with various licenses:

**OpenTelemetry Components**
- OpenTelemetry SDKs: Apache License 2.0
- OpenTelemetry Collector: Apache License 2.0

**Observability Stack**
- Jaeger: Apache License 2.0
- Prometheus: Apache License 2.0
- Grafana: AGPL v3 (for open-source version)

**Container Images**
- Node.js: MIT License
- Python: Python Software Foundation License
- Go: BSD-style License
- Alpine Linux: Various licenses

**AWS Services**
- Usage subject to AWS Customer Agreement
- Pricing and terms available at aws.amazon.com

### Attribution

This project was created to demonstrate OpenTelemetry capabilities on AWS EKS. It builds upon the excellent work of the OpenTelemetry community and incorporates best practices from various open-source projects.

**Acknowledgments:**
- OpenTelemetry Community for the comprehensive observability framework
- AWS for providing robust cloud infrastructure services
- Kubernetes Community for the container orchestration platform
- The maintainers of Jaeger, Prometheus, and Grafana for excellent observability tools

---

## Support and Community

For questions, issues, or discussions about this demo:

- **GitHub Issues**: Report bugs and request features
- **GitHub Discussions**: Ask questions and share experiences
- **OpenTelemetry Community**: Join the broader OpenTelemetry community discussions
- **AWS EKS Documentation**: Reference official AWS documentation for EKS-specific questions

**Disclaimer**: This project is for educational and demonstration purposes. It is not intended for production use without appropriate security hardening, monitoring, and operational procedures.

---

*Last updated: August 2025*
*Author: Manus AI*
*Version: 1.0.0*

