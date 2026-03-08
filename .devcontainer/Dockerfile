# Dockerfile for GitHub Codespaces development environment
# Extends Microsoft's universal image with project-specific tools

FROM mcr.microsoft.com/devcontainers/universal:latest

# Install additional tools and utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    jq \
    yq \
    curl \
    wget \
    git-lfs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Pre-install common npm packages globally
RUN npm install -g \
    @github/copilot@latest \
    @bradygaster/squad-cli@latest \
    eslint \
    prettier \
    typescript \
    ts-node \
    --prefer-offline --no-audit

# Create copilot config directory
RUN mkdir -p /home/codespace/.copilot

# Set default shell
ENV SHELL=/bin/bash

# Set working directory
WORKDIR /workspaces/tamresearch1

LABEL maintainer="B'Elanna (Infrastructure Expert)" \
      description="Development container for tamresearch1 with Copilot CLI, Squad, and MCP support" \
      version="1.0"
