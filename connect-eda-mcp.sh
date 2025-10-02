#!/bin/bash
# Wrapper script to connect to EDA MCP server in OpenShift
oc exec -i deployment/aap-mcp-eda -n aap-mcp-server -- python eda.py

