#!/bin/bash

# Setup script to configure Cursor to use OpenShift MCP servers

set -e

echo "=========================================="
echo "Cursor MCP OpenShift Configuration Setup"
echo "=========================================="
echo ""

# Check if oc is available
if ! command -v oc &> /dev/null; then
    echo "❌ Error: oc CLI not found. Please install OpenShift CLI first."
    echo "   Install with: brew install openshift-cli"
    exit 1
fi

# Check if logged into OpenShift
if ! oc whoami &> /dev/null; then
    echo "❌ Error: Not logged into OpenShift."
    echo "   Please run: oc login <your-openshift-url>"
    exit 1
fi

echo "✓ OpenShift CLI is available"
echo "✓ Logged in as: $(oc whoami)"
echo ""

# Check if pods are running
echo "Checking OpenShift MCP pods..."
if ! oc get pods -n aap-mcp-server &> /dev/null; then
    echo "❌ Error: Cannot access aap-mcp-server namespace"
    exit 1
fi

RUNNING_PODS=$(oc get pods -n aap-mcp-server --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')

if [ "$RUNNING_PODS" -eq "4" ]; then
    echo "✓ All 4 MCP pods are running"
else
    echo "⚠ Warning: Expected 4 running pods, found $RUNNING_PODS"
    oc get pods -n aap-mcp-server
fi

echo ""

# Backup existing config
CURSOR_CONFIG="$HOME/.cursor/mcp.json"
if [ -f "$CURSOR_CONFIG" ]; then
    BACKUP_FILE="$CURSOR_CONFIG.backup-$(date +%Y%m%d-%H%M%S)"
    echo "Creating backup of existing configuration..."
    cp "$CURSOR_CONFIG" "$BACKUP_FILE"
    echo "✓ Backup saved to: $BACKUP_FILE"
    echo ""
fi

# Collect credentials for local servers (if needed)
AAP_TOKEN=""
AAP_URL=""
EDA_TOKEN=""
EDA_URL=""
REDHAT_USERNAME=""
REDHAT_PASSWORD=""

# Ask user which configuration to use
echo "Choose configuration option:"
echo "  1) OpenShift servers only (recommended)"
echo "  2) Both local and OpenShift servers"
echo "  3) Cancel"
echo ""
read -p "Enter choice (1-3): " CHOICE

case $CHOICE in
    1)
        echo ""
        echo "Installing OpenShift-only configuration..."
        cp "$(dirname "$0")/cursor-mcp-openshift-config.json" "$CURSOR_CONFIG"
        echo "✓ Configuration updated"
        ;;
    2)
        echo ""
        echo "Creating merged configuration with both local and OpenShift servers..."
        echo ""
        echo "Please provide credentials for local MCP servers:"
        echo ""
        
        # Prompt for AAP credentials
        read -p "Enter AAP URL (e.g., https://aap.example.com/api/controller/v2): " AAP_URL
        read -s -p "Enter AAP Token: " AAP_TOKEN
        echo ""
        
        # Prompt for EDA credentials
        read -p "Enter EDA URL (e.g., https://aap.example.com/api/eda/v1): " EDA_URL
        read -s -p "Enter EDA Token: " EDA_TOKEN
        echo ""
        
        # Prompt for Red Hat credentials
        read -p "Enter Red Hat Username: " REDHAT_USERNAME
        read -s -p "Enter Red Hat Password: " REDHAT_PASSWORD
        echo ""
        echo ""
        cat > "$CURSOR_CONFIG" << EOF
{
  "mcpServers": {
    "ansible-local": {
      "command": "uv",
      "args": [
        "--directory",
        "$(dirname "$0")",
        "run",
        "ansible.py"
      ],
      "env": {
        "AAP_TOKEN": "$AAP_TOKEN",
        "AAP_URL": "$AAP_URL"
      }
    },
    "ansible-openshift": {
      "command": "$(dirname "$0")/connect-ansible-mcp.sh",
      "args": []
    },
    "eda-local": {
      "command": "uv",
      "args": [
        "--directory",
        "$(dirname "$0")",
        "run",
        "eda.py"
      ],
      "env": {
        "EDA_TOKEN": "$EDA_TOKEN",
        "EDA_URL": "$EDA_URL"
      }
    },
    "eda-openshift": {
      "command": "$(dirname "$0")/connect-eda-mcp.sh",
      "args": []
    },
    "ansible-lint-local": {
      "command": "uv",
      "args": [
        "--directory",
        "$(dirname "$0")",
        "run",
        "ansible-lint.py"
      ]
    },
    "ansible-lint-openshift": {
      "command": "$(dirname "$0")/connect-lint-mcp.sh",
      "args": []
    },
    "redhat-docs-local": {
      "command": "uv",
      "args": [
        "--directory",
        "$(dirname "$0")",
        "run",
        "redhat_docs.py"
      ],
      "env": {
        "REDHAT_USERNAME": "$REDHAT_USERNAME",
        "REDHAT_PASSWORD": "$REDHAT_PASSWORD"
      }
    },
    "redhat-docs-openshift": {
      "command": "$(dirname "$0")/connect-redhat-docs-mcp.sh",
      "args": []
    }
  }
}
EOF
        echo "✓ Configuration updated"
        ;;
    3)
        echo "Cancelled."
        exit 0
        ;;
    *)
        echo "Invalid choice. Cancelled."
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "✓ Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Restart Cursor to apply the changes"
echo "  2. Look for MCP servers in Cursor's status bar"
echo ""
echo "OpenShift MCP servers available:"
echo "  • ansible-openshift"
echo "  • eda-openshift"
echo "  • ansible-lint-openshift"
echo "  • redhat-docs-openshift"
echo ""
echo "Documentation: $(dirname "$0")/OPENSHIFT_MCP_CONNECTION.md"
echo ""

