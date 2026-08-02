#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

# ANSI color codes for premium terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

die() {
    error "$1"
    exit 1
}

# Ensure we are not running as root/sudo for the entire script
if [ "$EUID" -eq 0 ]; then
    die "Do NOT run this script as root/sudo directly. Run it as your regular user. The script will request sudo password only when cleaning up root-owned folders."
fi

echo -e "${CYAN}====================================================${NC}"
echo -e "${CYAN}   DevMind Extension Rebuilder & Reinstallation Suite${NC}"
echo -e "${CYAN}====================================================${NC}"

PROJECT_DIR="/var/www/html/DevMind"
cd "$PROJECT_DIR"

# 1. Cleanup Root-Owned Backups (Requires sudo)
if [ -d ".agents.bak" ] || [ -d "graphify-out.bak" ]; then
    log "Cleaning up old root-owned backup directories. Enter your sudo password if prompted:"
    sudo rm -rf .agents.bak graphify-out.bak AI_SETUP.md.bak
    success "Root backup directories cleaned."
fi

# 2. Cleanup User-Owned Dependencies & Configurations
log "Cleaning up previous user-level installations..."
rm -f "$HOME/.local/bin/devmind"
rm -rf "$HOME/.local/share/everything-claude-code"
rm -rf .agents graphify-out AI_SETUP.md DATABASE.md ARCHITECTURE.md SECURITY.md
success "User-level dependencies cleaned."

# 3. Setup Temp Node.js v20 for VS Code Packaging
NODE_TEMP_DIR="/tmp/devmind-node"
log "Preparing temporary Node.js environment to package extension..."
rm -rf "$NODE_TEMP_DIR"
mkdir -p "$NODE_TEMP_DIR"

log "Downloading Node.js v20.12.2..."
curl -fsSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.xz -o "$NODE_TEMP_DIR/node.tar.xz"
log "Extracting Node.js package..."
tar -xJf "$NODE_TEMP_DIR/node.tar.xz" -C "$NODE_TEMP_DIR"

# Set PATH to use temp Node version
export PATH="$NODE_TEMP_DIR/node-v20.12.2-linux-x64/bin:$PATH"
log "Using Node version: $(node -v)"

# 4. Compile and Package VS Code Extension
log "Building VS Code extension (vscode-extension)..."
cd vscode-extension

# Delete any existing VSIX file first
rm -f *.vsix

log "Installing package dependencies..."
npm install --ignore-scripts

log "Compiling TypeScript..."
npm run compile

log "Packaging VSIX file..."
npm run package

if [ -f devmind-vscode-1.0.0.vsix ]; then
    success "VSIX extension packaged successfully!"
else
    die "VSIX packaging failed."
fi

# Clean up temp Node folder
log "Cleaning up temporary Node files..."
rm -rf "$NODE_TEMP_DIR"

echo -e "${CYAN}====================================================${NC}"
echo -e "${GREEN}   DevMind VSIX Rebuilt Successfully! 🎉${NC}"
echo -e "${YELLOW}   Output: $PROJECT_DIR/vscode-extension/devmind-vscode-1.0.0.vsix${NC}"
echo -e "${CYAN}====================================================${NC}"
