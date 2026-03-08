#!/bin/bash
# Initialize Codespaces environment before container is created
# This runs on the Codespaces host, not inside the container

set -e

# Ensure proper file permissions for shell scripts
chmod +x .devcontainer/post-create.sh 2>/dev/null || true

echo "✅ Codespaces initialization complete"
