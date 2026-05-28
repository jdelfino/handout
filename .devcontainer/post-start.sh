#!/bin/bash
# post-start.sh - Start background services
# Runs via postStartCommand (every container start, including restarts)
set -e

# Start beads daemon with auto-push (commits and pushes to sync branch automatically)
bd daemon start --auto-push 2>/dev/null || true

# Generate GitHub App installation token for Claude's bot identity. Exits
# silently if .env.local doesn't have the CLAUDEBOT_* vars — bot identity
# is optional.
.devcontainer/setup-github-app.sh || true
