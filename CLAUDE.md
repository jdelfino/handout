# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

You are an experienced software engineer, building well-structured,
well-maintained software. You should not create or tolerate significant
duplication, architectural mess, or poor code organization. Clean small
messes up immediately, and file beads issues for resolving larger issues in
follow-on work.

## Project Overview

See [README.md](README.md) for the outward-facing description and
[`docs/design/KICKSTART.md`](docs/design/KICKSTART.md) for the v1 design doc.

**Quick context:** A GitHub-native replacement for GitHub Classroom. Built as
a GitHub App with a thin hosted backend. Next.js (App Router) on Cloud Run +
Postgres on Cloud SQL. Multi-tenant from day one; self-deploy is a design
baseline.

**Sibling project:** [Eval](https://github.com/jdelfino/eval) — separate
product, separate GCP project, shares the `.overlay/` problem-repo format.

## Status

Pre-alpha. The repo currently contains design docs, devcontainer/agent
tooling, and license. Application code has not been scaffolded yet.

## Project Layout (planned)

Will be filled in as the app is scaffolded. Per the design doc:

- `app/` — Next.js App Router pages and route handlers
- `lib/github/` — GitHub App / OAuth / API client abstractions
- `lib/db/` — Postgres access layer + RLS helpers
- `migrations/` — SQL migrations
- `docs/` — design docs, deploy recipes, setup guides
- `deploy/terraform/gcp/` — Terraform module for the hosted instance and any
  GCP self-deployer

## Development Principles

- **GitHub is the source of truth.** Don't duplicate state GitHub owns;
  project it for read performance.
- **Self-deploy is the baseline, not an extra.** No hardcoded project IDs,
  region names, domains, or SaaS-only code paths. All cloud touchpoints
  behind small abstractions with env-var defaults that work everywhere.
- **Read-side projection, not write-side enforcement** wherever possible.
- **Fail-fast configuration validation at startup.** Missing required env
  var → clear error, exit non-zero.
- **HTTP-only at the application layer.** TLS is the operator's problem.

## Testing

All production code changes MUST include tests. (Test stack TBD; will land
when the app is scaffolded.)

## AI-generated planning docs

Long-form planning docs (PLAN.md, IMPLEMENTATION.md, DESIGN.md, etc.) belong
in `history/` at the repo root. Keep the repo root clean. Permanent design
docs go in `docs/design/`.

## Issue Tracking (beads)

- **Issue-writing standard:** every issue must be self-contained — readable
  cold from its description alone. Required: 1-2 sentence summary
  (what + why), exact file paths to modify, numbered implementation steps,
  before→after example when applicable.
- **Dependency direction trap:** `bd dep add X Y` means "X needs Y" =
  Y blocks X. Temporal words ("Phase 1", "before", "first") invert your
  thinking. Verify with `bd blocked`.

## Git Hooks (lefthook)

Quality gates are enforced by lefthook git hooks. `--no-verify` is blocked
by a Claude Code PreToolUse hook.

Current hooks (will grow as the app is scaffolded):

- **Pre-commit (parallel):** `bd hooks run pre-commit`, gitleaks
- **Pre-push (parallel):** `bd hooks run pre-push`
- **Post-checkout / post-merge:** `bd hooks run …` (re-imports JSONL into
  the local Dolt store after branch switches and merges)
- **Prepare-commit-msg:** `bd hooks run prepare-commit-msg` (auto-trailers)

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).


<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
