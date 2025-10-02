#!/bin/bash

# Deploy AAP MCP Server to OpenShift
# Usage: ./deploy-to-openshift.sh <image-url>
# Example: ./deploy-to-openshift.sh quay.io/your-username/aap-mcp-server:latest

set -e

IMAGE_URL="${1}"

if [ -z "$IMAGE_URL" ]; then
  echo "Error: Image URL is required"
  echo "Usage: $0 <image-url>"
  echo "Example: $0 quay.io/your-username/aap-mcp-server:latest"
  exit 1
fi

echo "=================================================="
echo "Deploying AAP MCP Server to OpenShift"
echo "Image: $IMAGE_URL"
echo "=================================================="

# Check if oc is installed
if ! command -v oc &> /dev/null; then
  echo "Error: oc CLI not found. Please install OpenShift CLI."
  exit 1
fi

# Check if logged into OpenShift
if ! oc whoami &> /dev/null; then
  echo "Error: Not logged into OpenShift. Please run 'oc login' first."
  exit 1
fi

# Create namespace if it doesn't exist
echo ""
echo "Step 1: Creating namespace 'aap-mcp-server'..."
oc new-project aap-mcp-server 2>/dev/null || oc project aap-mcp-server

# Check if secret exists
if oc get secret aap-credentials -n aap-mcp-server &> /dev/null; then
  echo ""
  echo "Step 2: Secret 'aap-credentials' already exists."
  read -p "Do you want to update it? (y/n): " UPDATE_SECRET
  if [[ $UPDATE_SECRET =~ ^[Yy]$ ]]; then
    oc delete secret aap-credentials -n aap-mcp-server
    echo "Creating new secret..."
  else
    echo "Keeping existing secret."
  fi
fi

# Create or update secret if needed
if ! oc get secret aap-credentials -n aap-mcp-server &> /dev/null; then
  echo ""
  echo "Step 2: Creating secret with AAP credentials..."
  read -p "Enter AAP_TOKEN: " AAP_TOKEN
  read -p "Enter AAP_URL (e.g., https://your-aap.com/api/controller/v2): " AAP_URL
  read -p "Enter EDA_TOKEN (press Enter to use AAP_TOKEN): " EDA_TOKEN
  EDA_TOKEN="${EDA_TOKEN:-$AAP_TOKEN}"
  read -p "Enter EDA_URL (e.g., https://your-aap.com/api/eda/v1): " EDA_URL
  
  oc create secret generic aap-credentials \
    --from-literal=AAP_TOKEN="$AAP_TOKEN" \
    --from-literal=AAP_URL="$AAP_URL" \
    --from-literal=EDA_TOKEN="$EDA_TOKEN" \
    --from-literal=EDA_URL="$EDA_URL" \
    -n aap-mcp-server
  
  echo "Secret created successfully!"
fi

# Update deployment YAML with the image URL
echo ""
echo "Step 3: Updating deployment configuration with image URL..."
sed "s|quay.io/your-org/aap-mcp-server:latest|$IMAGE_URL|g" openshift-deployment.yaml > /tmp/openshift-deployment-temp.yaml

# Apply the deployment
echo ""
echo "Step 4: Deploying to OpenShift..."
oc apply -f /tmp/openshift-deployment-temp.yaml

# Clean up temp file
rm /tmp/openshift-deployment-temp.yaml

# Wait for deployments to be ready
echo ""
echo "Step 5: Waiting for pods to be ready..."
echo "This may take a few minutes..."

sleep 5

for component in ansible eda lint redhat-docs; do
  echo "Waiting for aap-mcp-$component..."
  oc rollout status deployment/aap-mcp-$component -n aap-mcp-server --timeout=5m || echo "Warning: Timeout waiting for aap-mcp-$component"
done

# Show deployment status
echo ""
echo "=================================================="
echo "Deployment Status"
echo "=================================================="
oc get pods -n aap-mcp-server

echo ""
echo "=================================================="
echo "Deployment Complete!"
echo "=================================================="
echo ""
echo "Useful commands:"
echo "  View pods:        oc get pods -n aap-mcp-server"
echo "  View logs:        oc logs -f deployment/aap-mcp-ansible -n aap-mcp-server"
echo "  Describe pod:     oc describe pod -l component=ansible -n aap-mcp-server"
echo "  Shell into pod:   oc rsh deployment/aap-mcp-ansible -n aap-mcp-server"
echo "  Delete all:       oc delete project aap-mcp-server"
echo ""

