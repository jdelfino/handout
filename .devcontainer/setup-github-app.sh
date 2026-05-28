#!/bin/bash
# setup-github-app.sh - Generate a GitHub App installation token for Claude.
# Safe to call frequently — skips regeneration if the token is < 55 minutes old.
#
# Reads bot-identity config from .env.local at the workspace root:
#   CLAUDEBOT_APP_ID
#   CLAUDEBOT_INSTALLATION_ID
#   CLAUDEBOT_PRIVATE_KEY_PATH (path to PEM, relative to workspace root)
#
# If any of those are missing or empty, exits 0 silently — bot identity is
# optional. See scripts/setup.sh for the registration walkthrough.
set -e

WORKSPACE_DIR="${WORKSPACE_DIR:-$(pwd)}"

# Load .env.local if present.
ENV_FILE="$WORKSPACE_DIR/.env.local"
if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a
fi

# Bail silently if bot identity isn't configured.
if [ -z "${CLAUDEBOT_APP_ID:-}" ] || [ -z "${CLAUDEBOT_INSTALLATION_ID:-}" ] || [ -z "${CLAUDEBOT_PRIVATE_KEY_PATH:-}" ]; then
    exit 0
fi

PEM_PATH="$WORKSPACE_DIR/$CLAUDEBOT_PRIVATE_KEY_PATH"
if [ ! -f "$PEM_PATH" ]; then
    echo "ERROR: CLAUDEBOT_PRIVATE_KEY_PATH points to $PEM_PATH but the file doesn't exist."
    exit 1
fi

# Wire up shell profile so GH_TOKEN auto-refreshes in every new shell.
_SCRIPT_PATH="$WORKSPACE_DIR/.devcontainer/setup-github-app.sh"
_PROFILE_BLOCK="# BEGIN: GitHub App token auto-refresh
if [ -f \"$_SCRIPT_PATH\" ]; then
    WORKSPACE_DIR=\"$WORKSPACE_DIR\" \"$_SCRIPT_PATH\" >/dev/null 2>&1 || true
    [ -f \"$WORKSPACE_DIR/.gh-app-token\" ] && export GH_TOKEN=\$(cat \"$WORKSPACE_DIR/.gh-app-token\")
fi
# END: GitHub App token auto-refresh"

for _rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$_rc" ]; then
        sed -i '/^# BEGIN: GitHub App token auto-refresh$/,/^# END: GitHub App token auto-refresh$/d' "$_rc"
        echo "" >> "$_rc"
        printf '%s\n' "$_PROFILE_BLOCK" >> "$_rc"
    fi
done
unset _SCRIPT_PATH _PROFILE_BLOCK _rc

# Skip token regeneration if fresh (< 55 minutes old; 5-min buffer before 1h expiry).
if [ -f "$WORKSPACE_DIR/.gh-app-token" ] && \
   find "$WORKSPACE_DIR/.gh-app-token" -mmin -55 -print -quit 2>/dev/null | grep -q .; then
    exit 0
fi

# Generate JWT (valid for 10 minutes, used only to get an installation token).
NOW=$(date +%s)
IAT=$((NOW - 60))
EXP=$((NOW + 600))

HEADER=$(echo -n '{"alg":"RS256","typ":"JWT"}' | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
PAYLOAD=$(echo -n "{\"iat\":${IAT},\"exp\":${EXP},\"iss\":\"${CLAUDEBOT_APP_ID}\"}" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

SIGNATURE=$(echo -n "${HEADER}.${PAYLOAD}" | \
    openssl dgst -sha256 -sign "$PEM_PATH" -binary | \
    openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

JWT="${HEADER}.${PAYLOAD}.${SIGNATURE}"

# Exchange JWT for an installation token (valid for 1 hour).
RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer ${JWT}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/app/installations/${CLAUDEBOT_INSTALLATION_ID}/access_tokens")

TOKEN=$(echo "$RESPONSE" | jq -r '.token // empty')

if [ -z "$TOKEN" ]; then
    echo "ERROR: Failed to generate GitHub App installation token"
    echo "Response: $RESPONSE"
    exit 1
fi

# Persist token for use by Claude.
echo "$TOKEN" > "$WORKSPACE_DIR/.gh-app-token"
chmod 600 "$WORKSPACE_DIR/.gh-app-token"

# Ensure no personal gh credentials are cached — when the bot identity is
# configured, GH_TOKEN (the App installation token) is the only auth path.
rm -f "$HOME/.config/gh/hosts.yml"

echo "GitHub App token generated (expires in 1 hour)"
