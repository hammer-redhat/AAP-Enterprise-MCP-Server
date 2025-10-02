#!/bin/bash
# Wrapper script to connect to Ansible Lint MCP server in OpenShift
oc exec -i deployment/aap-mcp-lint -n aap-mcp-server -- python ansible-lint.py

