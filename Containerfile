# Use Red Hat Universal Base Image (UBI) for OpenShift compatibility
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

# Set labels for better container metadata
LABEL name="aap-enterprise-mcp-server" \
      vendor="Ansible Community" \
      version="0.1.0" \
      summary="MCP Server for Ansible Automation Platform" \
      description="A comprehensive Model Context Protocol (MCP) server suite for Red Hat's automation and infrastructure ecosystem" \
      io.k8s.description="MCP server for AAP, EDA, ansible-lint, and Red Hat documentation" \
      io.k8s.display-name="AAP Enterprise MCP Server" \
      io.openshift.tags="ansible,automation,mcp,eda,openshift"

# Set working directory
WORKDIR /opt/app-root/src

# Install Python 3.11 and dependencies
RUN microdnf install -y \
    python3.11 \
    python3.11-pip \
    git \
    && microdnf clean all \
    && ln -sf /usr/bin/python3.11 /usr/bin/python3 \
    && ln -sf /usr/bin/python3.11 /usr/bin/python

# Install UV package manager
RUN python3.11 -m pip install --no-cache-dir uv

# Copy all source files (needed for uv to understand the project)
COPY pyproject.toml uv.lock ./
COPY ansible.py \
     eda.py \
     ansible-lint.py \
     redhat_docs.py \
     ./

# Install Python dependencies using UV in system mode
RUN uv pip install --system httpx mcp[cli] urllib3 ansible-lint ansible-core

# Copy documentation files
COPY README.md \
     README_REDHAT_DOCS.md \
     LICENSE \
     ./

# Create license directory required by UBI and set permissions for OpenShift
RUN mkdir -p /licenses && \
    cp LICENSE /licenses/LICENSE && \
    # Create non-root user for OpenShift
    useradd -u 1001 -r -g 0 -d /opt/app-root/src -s /sbin/nologin -c "Default Application User" default && \
    # Set proper permissions for OpenShift's arbitrary user IDs
    chown -R 1001:0 /opt/app-root && \
    chmod -R g=u /opt/app-root && \
    chmod -R g+rwx /opt/app-root

# Switch to non-root user for security (OpenShift best practice)
USER 1001

# Set Python path to include the application directory
ENV PYTHONPATH=/opt/app-root/src:$PYTHONPATH

# Health check (optional - adjust based on your server implementation)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import sys; sys.exit(0)"

# Create a wrapper script to keep stdin open for MCP stdio transport
RUN echo '#!/bin/bash' > /opt/app-root/src/run-mcp.sh && \
    echo 'tail -f /dev/null | python "$@"' >> /opt/app-root/src/run-mcp.sh && \
    chmod +x /opt/app-root/src/run-mcp.sh

# Default command - can be overridden in OpenShift deployment
# Runs the main Ansible MCP server by default  
CMD ["/opt/app-root/src/run-mcp.sh", "ansible.py"]

