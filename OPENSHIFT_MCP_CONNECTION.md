# Connecting Cursor to OpenShift MCP Servers

## Overview

Your Ansible MCP servers are now running in OpenShift. To connect Cursor to them, you have two options:

## Option 1: Use OpenShift MCP Servers (Recommended for Production)

Replace your current Cursor MCP configuration with the OpenShift version.

### Steps:

1. **Backup your current configuration:**
   ```bash
   cp ~/.cursor/mcp.json ~/.cursor/mcp.json.backup
   ```

2. **Copy the OpenShift configuration:**
   ```bash
   cp /Users/chrhamme/AAP-Enterprise-MCP-Server/cursor-mcp-openshift-config.json ~/.cursor/mcp.json
   ```

3. **Restart Cursor** to apply the changes.

4. **Verify connection:**
   - Open Cursor
   - Look for the MCP servers in the status bar
   - You should see: `ansible-openshift`, `eda-openshift`, `ansible-lint-openshift`, `redhat-docs-openshift`

### Configuration Details:

```json
{
  "mcpServers": {
    "ansible-openshift": {
      "command": "/Users/chrhamme/AAP-Enterprise-MCP-Server/connect-ansible-mcp.sh",
      "args": []
    },
    "eda-openshift": {
      "command": "/Users/chrhamme/AAP-Enterprise-MCP-Server/connect-eda-mcp.sh",
      "args": []
    },
    "ansible-lint-openshift": {
      "command": "/Users/chrhamme/AAP-Enterprise-MCP-Server/connect-lint-mcp.sh",
      "args": []
    },
    "redhat-docs-openshift": {
      "command": "/Users/chrhamme/AAP-Enterprise-MCP-Server/connect-redhat-docs-mcp.sh",
      "args": []
    }
  }
}
```

## Option 2: Run Both Local and OpenShift Servers

Keep both local and OpenShift servers available simultaneously.

### Merged Configuration:

```json
{
  "mcpServers": {
    "ansible-local": {
      "command": "uv",
      "args": [
        "--directory",
        "/Users/chrhamme/AAP-Enterprise-MCP-Server",
        "run",
        "ansible.py"
      ],
      "env": {
        "AAP_TOKEN": "<TOKEN>",
        "AAP_URL": "https://aap-aap.apps.virt.na-launch.com/api/controller/v2"
      }
    },
    "ansible-openshift": {
      "command": "/Users/chrhamme/AAP-Enterprise-MCP-Server/connect-ansible-mcp.sh",
      "args": []
    },
    "eda-local": {
      "command": "uv",
      "args": [
        "--directory",
        "/Users/chrhamme/AAP-Enterprise-MCP-Server",
        "run",
        "eda.py"
      ],
      "env": {
        "EDA_TOKEN": "<TOKEN>",
        "EDA_URL": "https://aap-aap.apps.virt.na-launch.com/api/eda/v1"
      }
    },
    "eda-openshift": {
      "command": "/Users/chrhamme/AAP-Enterprise-MCP-Server/connect-eda-mcp.sh",
      "args": []
    },
    "ansible-lint-local": {
      "command": "uv",
      "args": [
        "--directory",
        "/Users/chrhamme/AAP-Enterprise-MCP-Server",
        "run",
        "ansible-lint.py"
      ]
    },
    "ansible-lint-openshift": {
      "command": "/Users/chrhamme/AAP-Enterprise-MCP-Server/connect-lint-mcp.sh",
      "args": []
    },
    "redhat-docs-local": {
      "command": "uv",
      "args": [
        "--directory",
        "/Users/chrhamme/AAP-Enterprise-MCP-Server",
        "run",
        "redhat_docs.py"
      ],
      "env": {
        "REDHAT_USERNAME": "",
        "REDHAT_PASSWORD": ""
      }
    },
    "redhat-docs-openshift": {
      "command": "/Users/chrhamme/AAP-Enterprise-MCP-Server/connect-redhat-docs-mcp.sh",
      "args": []
    }
  }
}
```

## Prerequisites

1. **oc CLI must be installed and in PATH**
2. **You must be logged into OpenShift:**
   ```bash
   oc login <your-openshift-url>
   ```

3. **Verify connection to OpenShift:**
   ```bash
   oc get pods -n aap-mcp-server
   ```

## Testing the Connection

Test each wrapper script manually:

```bash
# Test Ansible MCP
./connect-ansible-mcp.sh
# Press Ctrl+C to exit

# Test EDA MCP
./connect-eda-mcp.sh
# Press Ctrl+C to exit

# Test Lint MCP
./connect-lint-mcp.sh
# Press Ctrl+C to exit

# Test Red Hat Docs MCP
./connect-redhat-docs-mcp.sh
# Press Ctrl+C to exit
```

## Troubleshooting

### Issue: "oc: command not found"

**Solution:** Install the OpenShift CLI:
```bash
# macOS
brew install openshift-cli
```

### Issue: "Not logged into OpenShift"

**Solution:**
```bash
oc login https://api.virt.na-launch.com:6443
```

### Issue: "Error from server (NotFound): deployments.apps not found"

**Solution:** Verify the deployment is running:
```bash
oc get pods -n aap-mcp-server
```

### Issue: MCP server not responding in Cursor

**Solution:**
1. Check OpenShift connection: `oc whoami`
2. Verify pods are running: `oc get pods -n aap-mcp-server`
3. Check pod logs: `oc logs deployment/aap-mcp-ansible -n aap-mcp-server`
4. Test wrapper script manually
5. Restart Cursor

## Benefits of OpenShift Deployment

✅ **Centralized:** Run servers in one location, accessible from anywhere  
✅ **Scalable:** Can increase replicas if needed  
✅ **Persistent:** Servers stay running 24/7  
✅ **Shared:** Multiple users can access the same servers  
✅ **Managed:** OpenShift handles restarts and health checks  

## Switching Between Local and OpenShift

You can easily switch by updating `~/.cursor/mcp.json`:

```bash
# Use OpenShift servers
cp cursor-mcp-openshift-config.json ~/.cursor/mcp.json

# Use local servers
cp ~/.cursor/mcp.json.backup ~/.cursor/mcp.json
```

Then restart Cursor.

## Notes

- The wrapper scripts use `oc exec -i` to pipe stdin/stdout to the pods
- MCP servers in OpenShift use stdio transport
- Credentials are stored in OpenShift secrets (`aap-credentials`)
- Each server runs in its own pod for isolation

