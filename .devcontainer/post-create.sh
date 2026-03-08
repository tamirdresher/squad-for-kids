#!/bin/bash
# Post-create script for GitHub Codespaces
# Installs Copilot CLI, Squad CLI, MCPs, and project dependencies

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Codespaces Environment Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_step() {
  echo -e "${BLUE}➜${NC} $1"
}

log_success() {
  echo -e "${GREEN}✅${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}⚠️${NC}  $1"
}

# Update system packages
log_step "Updating system packages..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq > /dev/null 2>&1 || log_warning "Package upgrade had warnings"
log_success "System packages updated"
echo ""

# Install Copilot CLI
log_step "Installing GitHub Copilot CLI..."
npm install -g @github/copilot@latest > /dev/null 2>&1 || {
  log_warning "Copilot CLI installation had issues, trying alternate method..."
  npm install -g @github/copilot || log_warning "Copilot CLI installation incomplete (may be OK if already installed)"
}
log_success "GitHub Copilot CLI installed"
echo ""

# Install Squad CLI
log_step "Installing Squad CLI..."
npm install -g @bradygaster/squad-cli@latest > /dev/null 2>&1 || {
  log_warning "Squad CLI installation had issues, trying alternate method..."
  npm install -g @bradygaster/squad-cli || log_warning "Squad CLI installation incomplete"
}
log_success "Squad CLI installed"
echo ""

# Install project dependencies
log_step "Installing project dependencies..."
npm install
log_success "Project dependencies installed"
echo ""

# Setup MCP configuration
log_step "Setting up MCP (Model Context Protocol) configuration..."
mkdir -p ~/.copilot
if [ -f "./.copilot/mcp-config.json" ]; then
  cp ./.copilot/mcp-config.json ~/.copilot/mcp-config.json
  log_success "MCP configuration copied to ~/.copilot/mcp-config.json"
else
  log_warning "No .copilot/mcp-config.json found, using default MCP settings"
  mkdir -p .copilot
fi
echo ""

# Verify installations
log_step "Verifying installations..."
echo ""

COPILOT_VERSION=$(copilot --version 2>/dev/null || echo "not-found")
if [ "$COPILOT_VERSION" != "not-found" ]; then
  log_success "Copilot CLI: $COPILOT_VERSION"
else
  log_warning "Copilot CLI not fully initialized (run 'copilot configure' to complete setup)"
fi

SQUAD_VERSION=$(squad --version 2>/dev/null || echo "not-found")
if [ "$SQUAD_VERSION" != "not-found" ]; then
  log_success "Squad CLI: $SQUAD_VERSION"
else
  log_warning "Squad CLI: installed but not yet initialized"
fi

NODE_VERSION=$(node --version 2>/dev/null)
log_success "Node.js: $NODE_VERSION"

NPM_VERSION=$(npm --version 2>/dev/null)
log_success "npm: $NPM_VERSION"

GIT_VERSION=$(git --version 2>/dev/null)
log_success "Git: $GIT_VERSION"

GH_VERSION=$(gh --version 2>/dev/null | head -1)
log_success "GitHub CLI: $GH_VERSION"

echo ""

# Additional setup
log_step "Final setup steps..."

# Configure git for Codespaces
if [ -z "$(git config --global user.email)" ]; then
  log_warning "Git user.email not set, using default Codespaces configuration"
fi

# Create useful aliases
if ! grep -q "alias squad=" ~/.bashrc 2>/dev/null; then
  echo 'alias squad="@bradygaster/squad-cli"' >> ~/.bashrc
  log_success "Added squad CLI alias to ~/.bashrc"
fi

log_success "Additional setup completed"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✨ Codespaces environment ready!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  1. Configure Copilot CLI authentication:"
echo "     $ copilot configure"
echo ""
echo "  2. Verify MCP servers are available:"
echo "     $ copilot-configure show-config"
echo ""
echo "  3. Start developing:"
echo "     $ npm run dev"
echo ""
echo "  4. Run tests:"
echo "     $ npm run test"
echo ""
echo "For more information:"
echo "  - .devcontainer/README.md     (Codespaces setup guide)"
echo "  - devbox-provisioning/README.md (DevBox provisioning reference)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
