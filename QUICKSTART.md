# Quick Start: Deploy to OpenShift

## Prerequisites
- ✅ OpenShift cluster access
- ✅ `oc` CLI installed and configured
- ✅ `podman` or `docker` installed
- ✅ Container image built (`aap-mcp-server:latest`)
- ✅ AAP credentials (token and URL)

## Automated Deployment (Recommended)

### Step 1: Push Image to Registry

**Option A: Quay.io (Public Registry)**
```bash
# Login to Quay.io
podman login quay.io

# Tag and push (replace 'chrhamme' with your username)
podman tag aap-mcp-server:latest quay.io/chrhamme/aap-mcp-server:latest
podman push quay.io/chrhamme/aap-mcp-server:latest
```

**Option B: OpenShift Internal Registry**
```bash
# Expose the internal registry (if not already exposed)
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge

# Get the registry route
REGISTRY=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}')

# Login to internal registry
podman login -u $(oc whoami) -p $(oc whoami -t) $REGISTRY --tls-verify=false

# Tag and push
podman tag aap-mcp-server:latest $REGISTRY/aap-mcp-server/aap-mcp-server:latest
podman push $REGISTRY/aap-mcp-server/aap-mcp-server:latest --tls-verify=false
```

### Step 2: Run Deployment Script

```bash
# Login to OpenShift first
oc login --server=https://your-openshift-api:6443

# Run the deployment script with your image URL
./deploy-to-openshift.sh quay.io/chrhamme/aap-mcp-server:latest
```

The script will:
1. Create the `aap-mcp-server` namespace
2. Prompt for AAP credentials and create a secret
3. Deploy all 4 MCP servers (ansible, eda, lint, redhat-docs)
4. Wait for pods to be ready
5. Display the deployment status

## Manual Deployment

If you prefer to deploy manually:

### Step 1: Login to OpenShift
```bash
oc login --server=https://your-openshift-api:6443
```

### Step 2: Create Project
```bash
oc new-project aap-mcp-server
```

### Step 3: Create Secret
```bash
oc create secret generic aap-credentials \
  --from-literal=AAP_TOKEN="your-aap-token-here" \
  --from-literal=AAP_URL="https://your-aap.com/api/controller/v2" \
  --from-literal=EDA_TOKEN="your-eda-token-here" \
  --from-literal=EDA_URL="https://your-aap.com/api/eda/v1"
```

### Step 4: Update and Deploy YAML

Edit `openshift-deployment.yaml` and replace:
```yaml
image: quay.io/your-org/aap-mcp-server:latest
```

With your actual image URL, then:
```bash
oc apply -f openshift-deployment.yaml
```

## Verification

### Check Pod Status
```bash
oc get pods -n aap-mcp-server
```

Expected output:
```
NAME                                  READY   STATUS    RESTARTS   AGE
aap-mcp-ansible-xxxxxxxxx-xxxxx      1/1     Running   0          2m
aap-mcp-eda-xxxxxxxxx-xxxxx          1/1     Running   0          2m
aap-mcp-lint-xxxxxxxxx-xxxxx         1/1     Running   0          2m
aap-mcp-redhat-docs-xxxxxxxxx-xxxxx  1/1     Running   0          2m
```

### View Logs
```bash
# Ansible server logs
oc logs -f deployment/aap-mcp-ansible -n aap-mcp-server

# EDA server logs
oc logs -f deployment/aap-mcp-eda -n aap-mcp-server

# Lint server logs
oc logs -f deployment/aap-mcp-lint -n aap-mcp-server

# RedHat Docs server logs
oc logs -f deployment/aap-mcp-redhat-docs -n aap-mcp-server
```

### Test Connectivity
```bash
# Shell into the ansible pod
oc rsh deployment/aap-mcp-ansible -n aap-mcp-server

# Inside the pod, test the connection
python -c "
import os
import httpx
url = os.getenv('AAP_URL')
token = os.getenv('AAP_TOKEN')
headers = {'Authorization': f'Bearer {token}'}
response = httpx.get(f'{url}/job_templates/', headers=headers, verify=False)
print(f'Status: {response.status_code}')
print(f'Templates: {response.json().get(\"count\", 0)}')
"
```

## Troubleshooting

### Pods in ImagePullBackOff
```bash
# Check pod events
oc describe pod -l component=ansible -n aap-mcp-server

# Solution: Verify image URL and registry credentials
oc get secret -n aap-mcp-server
```

### Pods in CrashLoopBackOff
```bash
# Check logs for errors
oc logs deployment/aap-mcp-ansible -n aap-mcp-server --previous

# Common issues:
# 1. Missing/invalid AAP credentials
# 2. Wrong AAP_URL format
# 3. Network connectivity to AAP server
```

### Update Credentials
```bash
# Delete old secret
oc delete secret aap-credentials -n aap-mcp-server

# Create new secret
oc create secret generic aap-credentials \
  --from-literal=AAP_TOKEN="new-token" \
  --from-literal=AAP_URL="https://your-aap.com/api/controller/v2" \
  --from-literal=EDA_TOKEN="new-token" \
  --from-literal=EDA_URL="https://your-aap.com/api/eda/v1"

# Restart deployments to pick up new credentials
oc rollout restart deployment/aap-mcp-ansible -n aap-mcp-server
oc rollout restart deployment/aap-mcp-eda -n aap-mcp-server
oc rollout restart deployment/aap-mcp-redhat-docs -n aap-mcp-server
```

## Updating the Deployment

### Update to New Image Version
```bash
# Build and push new version
podman build -t aap-mcp-server:v2 -f Containerfile .
podman tag aap-mcp-server:v2 quay.io/chrhamme/aap-mcp-server:v2
podman push quay.io/chrhamme/aap-mcp-server:v2

# Update all deployments
oc set image deployment/aap-mcp-ansible ansible=quay.io/chrhamme/aap-mcp-server:v2 -n aap-mcp-server
oc set image deployment/aap-mcp-eda eda=quay.io/chrhamme/aap-mcp-server:v2 -n aap-mcp-server
oc set image deployment/aap-mcp-lint lint=quay.io/chrhamme/aap-mcp-server:v2 -n aap-mcp-server
oc set image deployment/aap-mcp-redhat-docs redhat-docs=quay.io/chrhamme/aap-mcp-server:v2 -n aap-mcp-server

# Check rollout status
oc rollout status deployment/aap-mcp-ansible -n aap-mcp-server
```

### Rollback to Previous Version
```bash
oc rollout undo deployment/aap-mcp-ansible -n aap-mcp-server
```

## Scaling

### Scale Up/Down
```bash
# Scale to 2 replicas
oc scale deployment/aap-mcp-ansible --replicas=2 -n aap-mcp-server

# Scale to 0 (pause)
oc scale deployment/aap-mcp-ansible --replicas=0 -n aap-mcp-server
```

### Auto-scaling
```bash
# Create horizontal pod autoscaler
oc autoscale deployment/aap-mcp-ansible \
  --min=1 \
  --max=5 \
  --cpu-percent=80 \
  -n aap-mcp-server
```

## Resource Monitoring

### Check Resource Usage
```bash
# Get resource usage
oc adm top pods -n aap-mcp-server

# Get events
oc get events -n aap-mcp-server --sort-by='.lastTimestamp'
```

## Cleanup

### Delete Everything
```bash
# Delete the entire project
oc delete project aap-mcp-server
```

### Delete Specific Components
```bash
# Delete only the ansible deployment
oc delete deployment aap-mcp-ansible -n aap-mcp-server

# Delete all but keep the secret
oc delete deployment --all -n aap-mcp-server
```

## Next Steps

Once deployed, you can:
1. Access the MCP servers from your AI assistant (Claude, etc.)
2. Configure MCP clients to connect to the OpenShift services
3. Set up monitoring and alerting
4. Integrate with CI/CD pipelines

For more details, see:
- [BUILD.md](BUILD.md) - Complete build documentation
- [README.md](README.md) - Full feature documentation
- [openshift-deployment.yaml](openshift-deployment.yaml) - Deployment configuration

