#!/bin/bash
set -e

# SimpleReact Deployment Script
# This script automates the build and deployment of the SimpleReact application
# including frontend, backend, and observability components.

# Display help information
show_help() {
  echo "SimpleReact Deployment Script"
  echo "Usage: ./deploy.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -e, --environment ENV   Specify deployment environment (local, dev, prod) [default: local]"
  echo "  -b, --build             Build Docker images"
  echo "  -p, --push              Push Docker images to registry"
  echo "  -d, --deploy            Deploy to Kubernetes"
  echo "  -o, --observability     Deploy observability stack (Jaeger/Elasticsearch/Kibana)"
  echo "  -h, --help              Show this help message"
  echo ""
  echo "Examples:"
  echo "  ./deploy.sh -b -d                  # Build and deploy locally"
  echo "  ./deploy.sh -e dev -b -p -d        # Build, push, and deploy to dev environment"
  echo "  ./deploy.sh -e prod -d -o          # Deploy to production with observability"
}

# Default values
ENVIRONMENT="local"
BUILD=false
PUSH=false
DEPLOY=false
OBSERVABILITY=false
REGISTRY="ghcr.io"
REPO_NAME="asekho-gova/simplereact"
FRONTEND_IMAGE_NAME="${REGISTRY}/${REPO_NAME}-frontend"
BACKEND_IMAGE_NAME="${REGISTRY}/${REPO_NAME}-backend"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -e|--environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    -b|--build)
      BUILD=true
      shift
      ;;
    -p|--push)
      PUSH=true
      shift
      ;;
    -d|--deploy)
      DEPLOY=true
      shift
      ;;
    -o|--observability)
      OBSERVABILITY=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Validate environment
if [[ "$ENVIRONMENT" != "local" && "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
  echo "Error: Invalid environment. Must be 'local', 'dev', or 'prod'."
  exit 1
fi

# Set environment-specific variables
case $ENVIRONMENT in
  local)
    NAMESPACE="simplereact-local"
    FRONTEND_TAG="latest"
    BACKEND_TAG="latest"
    ;;
  dev)
    NAMESPACE="simplereact-dev"
    FRONTEND_TAG="dev"
    BACKEND_TAG="dev"
    ;;
  prod)
    NAMESPACE="simplereact-prod"
    FRONTEND_TAG="stable"
    BACKEND_TAG="stable"
    ;;
esac

# Function to log messages with timestamps
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check for required tools
check_requirements() {
  log "Checking requirements..."
  
  local missing_tools=()
  
  if ! command_exists docker; then
    missing_tools+=("docker")
  fi
  
  if [[ "$DEPLOY" == true ]]; then
    if ! command_exists kubectl; then
      missing_tools+=("kubectl")
    fi
    
    if ! command_exists helm; then
      missing_tools+=("helm")
    fi
  fi
  
  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    log "Error: The following required tools are missing:"
    for tool in "${missing_tools[@]}"; do
      echo "  - $tool"
    done
    log "Please install the missing tools and try again."
    exit 1
  fi
  
  log "All requirements satisfied."
}

# Build Docker images
build_images() {
  log "Building Docker images..."
  
  # Build frontend image
  log "Building frontend image: $FRONTEND_IMAGE_NAME:$FRONTEND_TAG"
  docker build -t "$FRONTEND_IMAGE_NAME:$FRONTEND_TAG" ./Frontend/simple-react-app
  
  # Build backend image
  log "Building backend image: $BACKEND_IMAGE_NAME:$BACKEND_TAG"
  docker build -t "$BACKEND_IMAGE_NAME:$BACKEND_TAG" ./Backend/SimpleReact.API
  
  log "Docker images built successfully."
}

# Push Docker images to registry
push_images() {
  if [[ "$ENVIRONMENT" == "local" ]]; then
    log "Skipping push for local environment."
    return
  fi
  
  log "Pushing Docker images to registry..."
  
  # Check if logged in to registry
  if ! docker info | grep -q "Username"; then
    log "Not logged in to Docker registry. Please run 'docker login $REGISTRY' first."
    exit 1
  fi
  
  # Push frontend image
  log "Pushing frontend image: $FRONTEND_IMAGE_NAME:$FRONTEND_TAG"
  docker push "$FRONTEND_IMAGE_NAME:$FRONTEND_TAG"
  
  # Push backend image
  log "Pushing backend image: $BACKEND_IMAGE_NAME:$BACKEND_TAG"
  docker push "$BACKEND_IMAGE_NAME:$BACKEND_TAG"
  
  log "Docker images pushed successfully."
}

# Deploy to Kubernetes
deploy_kubernetes() {
  log "Deploying to Kubernetes in namespace: $NAMESPACE"
  
  # Create namespace if it doesn't exist
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    log "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
  fi
  
  # Update Helm dependencies
  log "Updating Helm dependencies..."
  cd helm-charts
  helm dependency update
  
  # Set environment-specific values
  local values_file=""
  local set_values=(
    "frontend.image.repository=$FRONTEND_IMAGE_NAME"
    "frontend.image.tag=$FRONTEND_TAG"
    "backend.image.repository=$BACKEND_IMAGE_NAME"
    "backend.image.tag=$BACKEND_TAG"
  )
  
  # Add observability settings if enabled
  if [[ "$OBSERVABILITY" == true ]]; then
    set_values+=(
      "observability.jaeger.enabled=true"
    )
    
    # Enable Elasticsearch and Kibana in production
    if [[ "$ENVIRONMENT" == "prod" ]]; then
      set_values+=(
        "observability.elasticsearch.enabled=true"
        "observability.kibana.enabled=true"
      )
    fi
  else
    set_values+=(
      "observability.jaeger.enabled=false"
      "observability.elasticsearch.enabled=false"
      "observability.kibana.enabled=false"
    )
  fi
  
  # Convert set_values array to Helm --set arguments
  local set_args=""
  for value in "${set_values[@]}"; do
    set_args="$set_args --set $value"
  done
  
  # Deploy with Helm
  log "Deploying with Helm..."
  # shellcheck disable=SC2086
  helm upgrade --install simplereact . \
    --namespace "$NAMESPACE" \
    $set_args
  
  log "Deployment completed successfully."
  
  # Get service information
  log "Services deployed:"
  kubectl get services -n "$NAMESPACE"
  
  # Get ingress information if available
  if kubectl api-resources | grep -q "ingress"; then
    log "Ingress resources:"
    kubectl get ingress -n "$NAMESPACE"
  fi
}

# Deploy observability stack with Docker Compose (for local development)
deploy_observability_local() {
  log "Deploying observability stack locally with Docker Compose..."
  
  cd Observability/Jaeger
  docker-compose up -d
  
  log "Observability stack deployed locally."
  log "Jaeger UI available at: http://localhost:16686"
  
  if grep -q "elasticsearch" docker-compose.yaml; then
    log "Elasticsearch available at: http://localhost:9200"
    log "Kibana available at: http://localhost:5601"
  fi
}

# Main execution
main() {
  log "Starting SimpleReact deployment for environment: $ENVIRONMENT"
  
  check_requirements
  
  if [[ "$BUILD" == true ]]; then
    build_images
  fi
  
  if [[ "$PUSH" == true ]]; then
    push_images
  fi
  
  if [[ "$DEPLOY" == true ]]; then
    if [[ "$ENVIRONMENT" == "local" ]]; then
      log "For local deployment, please run the following commands manually:"
      log "  - Backend: cd Backend/SimpleReact.API && dotnet run"
      log "  - Frontend: cd Frontend/simple-react-app && npm run dev"
      
      if [[ "$OBSERVABILITY" == true ]]; then
        deploy_observability_local
      fi
    else
      deploy_kubernetes
    fi
  fi
  
  log "Deployment script completed."
}

# Execute main function
main
