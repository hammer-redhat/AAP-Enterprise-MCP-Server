#!/bin/bash
# Wrapper script to connect to Ansible MCP server in OpenShift
oc exec -i deployment/aap-mcp-ansible -n aap-mcp-server -- python ansible.py

