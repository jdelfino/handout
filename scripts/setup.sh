#!/usr/bin/env bash
# Handout setup walkthrough. Idempotent — safe to re-run any time.
#
# Does exactly two things:
#   1. If .env.local doesn't exist, copy .env.local.example to it.
#   2. Print the setup steps to stdout.
#
# Editing .env.local is your job.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [ ! -f .env.local ]; then
  cp .env.local.example .env.local
  echo "Created .env.local from template."
  echo
fi

cat <<'EOF'
Handout setup
=============

All sections are optional. Fill in the ones you need; leave the others
blank in .env.local.

--------------------------------------------------------------------
Section: Bot identity (optional)
--------------------------------------------------------------------
A GitHub App that gives Claude a separate identity for commits and PRs
made from this devcontainer. Without it, Claude operates under your
own user identity — fine for most setups.

Steps:

1. Register a GitHub App:
     https://github.com/settings/apps/new
   Suggested:
     - Name: "<your-handle>-claudebot" (or anything globally unique)
     - Homepage URL: anything you like
     - Webhook: uncheck "Active" — the bot doesn't receive webhooks
     - Permissions (Repository):
         Contents: Read & write
         Pull requests: Read & write
         Issues: Read & write
   Click "Create GitHub App". Note the App ID at the top of the page.

2. Generate a private key (General tab → Private keys →
   "Generate a private key"). A .pem file downloads.
   Save it as .gh-app-private-key.pem in the repo root (gitignored).

3. Install the App on this repo:
     - Left sidebar of the App page: "Install App"
     - Pick your account, select handout (or "All repositories")
     - After install, visit https://github.com/settings/installations,
       click "Configure" on your App, and copy the installation ID from
       the URL (the trailing number).

4. Fill in .env.local:
     CLAUDEBOT_APP_ID=<app id from step 1>
     CLAUDEBOT_INSTALLATION_ID=<installation id from step 3>
     CLAUDEBOT_PRIVATE_KEY_PATH=.gh-app-private-key.pem

5. (Re)open the devcontainer, or run:
     .devcontainer/setup-github-app.sh
   This mints an installation token and wires it into GH_TOKEN for
   every shell in the container. Tokens auto-refresh hourly.

--------------------------------------------------------------------

Done.
EOF
