# =============================================================================
# Dockerfile — Containerized Ralph (Squad Work Monitor)
# infrastructure/k8s/ralph-dockerfile/Dockerfile
# POC for Squad-on-K8s (Issue #996)
#
# Ralph is a PowerShell 7+ agent that polls GitHub issues and dispatches
# work to Squad agents via the Copilot CLI (agency).
#
# Design decisions:
#   - PowerShell base image — Ralph is pwsh-native, requires pwsh >= 7
#   - GH_TOKEN injected at runtime via K8s Secret — NEVER baked into image
#   - .squad/ config mounted as a volume — live config without rebuilds
#   - Non-root user (ralph, UID 1000) for least-privilege operation
#   - Multi-stage build to keep runtime image lean
#
# Build:
#   # From this directory:
#   docker build -t squad-ralph:latest .
#   # From repo root:
#   docker build -f infrastructure/k8s/ralph-dockerfile/Dockerfile -t squad-ralph:latest .
#
# Run (local):
#   docker run \
#     -e GH_TOKEN=ghp_... \
#     -e GITHUB_REPOSITORY=tamirdresher/tamresearch1 \
#     -v $(pwd)/.squad:/app/.squad:ro \
#     -v $(pwd)/squad.config.ts:/app/squad.config.ts:ro \
#     squad-ralph:latest
#
# K8s deployment:
#   See ../docker-compose.yml for local multi-agent setup
#   See ../../helm/squad/ for Helm chart (ralph-deployment.yaml template)
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: deps — install system tools and Node.js packages
# ---------------------------------------------------------------------------
FROM mcr.microsoft.com/powershell:latest AS deps

WORKDIR /build

# System prerequisites
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20 LTS (required for Copilot CLI / agency)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Pre-install gh extensions while we have build context
RUN gh extension install github/gh-copilot 2>/dev/null || true

# ---------------------------------------------------------------------------
# Stage 2: runtime — lean image with only what Ralph needs
# ---------------------------------------------------------------------------
FROM mcr.microsoft.com/powershell:latest AS runtime

LABEL maintainer="squad-team" \
      description="Ralph — Squad Work Monitor (pod-per-agent K8s deployment)" \
      org.opencontainers.image.title="squad-ralph" \
      org.opencontainers.image.source="https://github.com/tamirdresher/tamresearch1" \
      org.opencontainers.image.licenses="MIT"

# Runtime system dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    gnupg \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20 LTS (agency/Copilot CLI runtime dependency)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Non-root user — least-privilege operation
# UID 1000 matches securityContext in ralph-deployment.yaml Helm template
# ---------------------------------------------------------------------------
RUN useradd -m -u 1000 -s /bin/bash ralph
ENV HOME=/home/ralph

# Copy gh extensions from deps stage
COPY --from=deps /root/.local/share/gh/extensions /home/ralph/.local/share/gh/extensions
RUN chown -R ralph:ralph /home/ralph/.local 2>/dev/null || true

# ---------------------------------------------------------------------------
# Application layout
#
#   /app/ralph-watch.ps1     — Ralph's main loop (baked in)
#   /app/.squad/             — Squad config  <- VOLUME MOUNT in K8s/local
#   /app/squad.config.ts     — Squad config  <- VOLUME MOUNT in K8s/local
#
# .squad/ and squad.config.ts are intentionally NOT copied here.
# In K8s: provided as ConfigMap volume mounts (see ralph-deployment.yaml)
# Locally: bind-mount with -v $(pwd)/.squad:/app/.squad:ro
# ---------------------------------------------------------------------------
WORKDIR /app

# Copy Ralph's main script (scripts/ helpers copied if present)
COPY ralph-watch.ps1 ./

RUN chown -R ralph:ralph /app

# ---------------------------------------------------------------------------
# Environment variables
#
# REQUIRED at runtime (inject via K8s Secret or docker run -e):
#   GH_TOKEN          — GitHub PAT (repo, issues, pull_requests scopes)
#                       In AKS production: replace with Workload Identity
#   GITHUB_REPOSITORY — owner/repo e.g. tamirdresher/tamresearch1
#
# OPTIONAL:
#   COPILOT_API_KEY        — Copilot/agency key if separate from GH_TOKEN
#   RALPH_INTERVAL_SECONDS — poll frequency in seconds (default: 300)
#   RALPH_LOG_LEVEL        — debug | info | warn | error
#   SQUAD_CONFIG_PATH      — path to squad.config.ts inside container
# ---------------------------------------------------------------------------
ENV GH_TOKEN="" \
    GITHUB_REPOSITORY="" \
    COPILOT_API_KEY="" \
    RALPH_INTERVAL_SECONDS="300" \
    RALPH_LOG_LEVEL="info" \
    SQUAD_CONFIG_PATH="/app/squad.config.ts" \
    GH_CONFIG_DIR="/home/ralph/.config/gh"

# Switch to non-root for all runtime operations
USER ralph

# ---------------------------------------------------------------------------
# Health check — verifies pwsh >= 7 and gh CLI are functional
# Matches the liveness probe in ralph-deployment.yaml
# ---------------------------------------------------------------------------
HEALTHCHECK \
    --interval=60s \
    --timeout=10s \
    --start-period=30s \
    --retries=3 \
    CMD ["pwsh", "-NoProfile", "-Command", \
         "if ($PSVersionTable.PSVersion.Major -ge 7 -and (Get-Command gh -ErrorAction SilentlyContinue)) { exit 0 } else { exit 1 }"]

# ---------------------------------------------------------------------------
# Entry point
# -NoProfile: skip profile scripts (faster + deterministic in containers)
# -ExecutionPolicy Bypass: required to run unsigned scripts
# ---------------------------------------------------------------------------
ENTRYPOINT ["pwsh", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "/app/ralph-watch.ps1"]
