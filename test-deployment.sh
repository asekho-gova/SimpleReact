#!/bin/bash
set -e

# Test script for SimpleReact deployment
echo "=== SimpleReact Deployment Testing ==="
echo "Testing Docker builds and deployment script functionality"

# Test frontend Dockerfile
echo -e "\n=== Testing Frontend Dockerfile ==="
if [ -f "./Frontend/simple-react-app/Dockerfile" ]; then
  echo "Frontend Dockerfile exists: OK"
  # Validate Dockerfile syntax
  docker parse ./Frontend/simple-react-app/Dockerfile 2>/dev/null && echo "Frontend Dockerfile syntax: OK" || echo "Frontend Dockerfile syntax: FAILED"
else
  echo "Frontend Dockerfile does not exist: FAILED"
fi

# Test backend Dockerfile
echo -e "\n=== Testing Backend Dockerfile ==="
if [ -f "./Backend/SimpleReact.API/Dockerfile" ]; then
  echo "Backend Dockerfile exists: OK"
  # Validate Dockerfile syntax
  docker parse ./Backend/SimpleReact.API/Dockerfile 2>/dev/null && echo "Backend Dockerfile syntax: OK" || echo "Backend Dockerfile syntax: FAILED"
else
  echo "Backend Dockerfile does not exist: FAILED"
fi

# Test Jaeger docker-compose
echo -e "\n=== Testing Jaeger docker-compose ==="
if [ -f "./Observability/Jaeger/docker-compose.yaml" ]; then
  echo "Jaeger docker-compose exists: OK"
  # Validate docker-compose syntax
  docker-compose -f ./Observability/Jaeger/docker-compose.yaml config 2>/dev/null && echo "Jaeger docker-compose syntax: OK" || echo "Jaeger docker-compose syntax: FAILED"
else
  echo "Jaeger docker-compose does not exist: FAILED"
fi

# Test Helm charts
echo -e "\n=== Testing Helm Charts ==="
if [ -d "./helm-charts" ]; then
  echo "Helm charts directory exists: OK"
  # Count number of charts
  chart_count=$(find ./helm-charts -name "Chart.yaml" | wc -l)
  echo "Found $chart_count Helm charts"
  
  # Validate main chart
  if [ -f "./helm-charts/Chart.yaml" ]; then
    echo "Main Helm chart exists: OK"
  else
    echo "Main Helm chart does not exist: FAILED"
  fi
  
  # Validate frontend chart
  if [ -f "./helm-charts/frontend/Chart.yaml" ]; then
    echo "Frontend Helm chart exists: OK"
  else
    echo "Frontend Helm chart does not exist: FAILED"
  fi
  
  # Validate backend chart
  if [ -f "./helm-charts/backend/Chart.yaml" ]; then
    echo "Backend Helm chart exists: OK"
  else
    echo "Backend Helm chart does not exist: FAILED"
  fi
  
  # Validate observability chart
  if [ -f "./helm-charts/observability/Chart.yaml" ]; then
    echo "Observability Helm chart exists: OK"
  else
    echo "Observability Helm chart does not exist: FAILED"
  fi
else
  echo "Helm charts directory does not exist: FAILED"
fi

# Test deployment script
echo -e "\n=== Testing Deployment Script ==="
if [ -f "./deploy.sh" ]; then
  echo "Deployment script exists: OK"
  # Test if script is executable
  if [ -x "./deploy.sh" ]; then
    echo "Deployment script is executable: OK"
    # Test help functionality
    ./deploy.sh --help && echo "Deployment script help: OK" || echo "Deployment script help: FAILED"
  else
    echo "Deployment script is not executable: FAILED"
  fi
else
  echo "Deployment script does not exist: FAILED"
fi

echo -e "\n=== Deployment Testing Complete ==="
