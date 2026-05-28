#!/bin/bash
# post-create.sh - Install tools and configure the development environment
# Runs via postCreateCommand (after container creation)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Fix phantom dirty-tree errors on Docker bind mounts (macOS Docker Desktop's
# fakeowner fs has unreliable timestamps). Without this, git rebase fails with
# "local changes would be overwritten by merge" even on a clean tree, because
# git's default stat check sees inode/uid/gid/mtime-ns mismatches and treats
# unchanged files as dirty.
git config --local core.checkStat minimal

# Install beads (git hooks are orchestrated by lefthook, see lefthook.yml)
curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash

# Install Claude Code
curl -fsSL https://claude.ai/install.sh | bash

# Fix ownership of node_modules volume (Docker named volumes default to root)
sudo chown -R vscode:vscode /workspaces/handout/node_modules || true

# Install lefthook and gitleaks via release binaries
curl -fsSL https://raw.githubusercontent.com/evilmartians/lefthook/master/install.sh | sudo sh
curl -fsSL https://raw.githubusercontent.com/gitleaks/gitleaks/master/scripts/install.sh | sudo sh -s -- -b /usr/local/bin
lefthook install || true

# Install system packages
sudo apt-get update
sudo apt-get install -y postgresql-client apt-transport-https ca-certificates gnupg

# Install Google Cloud SDK (for Cloud Run / Cloud SQL deploys)
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo 'deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main' | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
sudo apt-get update
sudo apt-get install -y google-cloud-cli

# Install Node deps so the container is ready to `npm run dev` immediately.
npm install
