# Handout — Kickstart Doc

> **Status**: design captured, ready to build.
> **Owner**: Joe Delfino (Delquillan LLC)
> **Last updated**: 2026-05-27

## What this is

A GitHub-native replacement for GitHub Classroom, built as a GitHub App with a thin hosted backend. Scope is intentionally narrow: distribute assignments to students by generating per-student repos from a template, and let the instructor see what students are doing. No autograding, no deadlines, no feedback UI in v1.

## Why now

GitHub announced on 2026-05-27 that Classroom decommissions on 2026-08-28. Many CS instructors are looking for a replacement before fall semester. The recommended partner solutions are mostly proprietary platforms requiring data migration; this is a GitHub-native, optionally self-hostable alternative that matches the model existing Classroom users already chose.

## Positioning

- **Primary v1 audience**: instructors whose pain is distribution + environment setup at scale (not grading). Autograde-pain instructors are v1.1 audience.
- **Differentiators vs Classroom**: GitHub-native (no migration), better default environment via Codespaces, multi-tenant hosted *plus* self-deploy option, no platform lock-in.
- **Relationship to Eval** (github.com/jdelfino/eval): sibling product, not a funnel. Shares the `.overlay/` problem repo format so content authored for one runs in the other. Architecturally distinct, operationally separate (separate GCP project).

---

## Scope

### v1 — included

- Instructor: install App on user account *or* org (both flows supported transparently)
- Instructor: create courses (logical containers, instructor-defined)
- Instructor: import roster from CSV
- Instructor: create assignment (point at template repo, give it a name + slug)
- Instructor: view assignment status across students (accepted, last push timestamp, link to repo)
- Instructor: "View as of `<datetime>`" — read-side projection rewriting repo links to `tree/<sha>` at the commit-at-that-time. No persistent state, no enforcement.
- Student: accept-assignment flow (OAuth → identity link if needed → repo generation → success page with Codespaces link)
- Multi-tenant codebase from day one (installation = tenant)
- Self-deploy support (single-tenant deployment = one row in `installations`)

### v1 — explicitly excluded

- **Autograde** — the grading workflow is the instructor's responsibility (lives in their template repo). The App neither injects nor runs grading. Defer to v1.1.
- **Hidden tests** — tests live in the student repo, visible. The `.overlay/`-fetched-at-grade-time pattern is v1.1.
- **Deadline enforcement** — `closes_at` field exists on the assignment record for *display only* in v1. Write-lock enforcement (revoke-write or archive on close) is v1.1.
- **Feedback UI** — rely entirely on GitHub-native (PR comments, line comments, Checks tab when autograde lands).
- **Submit action** — latest push is the submission. No state machine.
- **Group assignments** — one student per repo.
- **LMS integration** (LTI, Canvas roster sync) — CSV import only.
- **Central install with delegated instructor permissions** — v1 assumes the instructor is the org admin doing the install.

### v1.1 candidates (post-fall iteration)

- Autograde results aggregation (subscribe to `workflow_run.completed`, surface in assignment view).
- Write-lock enforcement at `closes_at` (revoke-write preferred over archive; reversible for late submissions).
- Hidden tests via `.overlay/` fetched at grade time using App-issued token.
- Cross-installation template support.
- Per-student deadline overrides / late-submission policy.

---

## Architecture

```
                                  ┌─────────────────────────┐
                                  │   GitHub (events)       │
   Instructor ─────────┐          │  • Installation         │
   (browser)           │          │  • Push                 │
                       │          │  • OAuth callbacks      │
   Student ────────────┤          └────────────┬────────────┘
   (browser)           │                       │ webhooks
                       │                       │
                       v                       v
                  ┌────────────────────────────────────┐
                  │     Cloud Run (one service)        │
                  │     Next.js (App Router):          │
                  │      • Instructor dashboard UI     │
                  │      • Student accept flow UI      │
                  │      • API routes:                 │
                  │         - OAuth callback           │
                  │         - Webhook receiver         │
                  │         - GitHub API calls         │
                  └────────┬──────────────────┬────────┘
                           │                  │
                           v                  v
                  ┌──────────────┐    ┌────────────────┐
                  │  Cloud SQL   │    │  Secret        │
                  │  Postgres    │    │  Manager       │
                  │              │    │  (App private  │
                  │  • installs  │    │   key,         │
                  │  • courses   │    │   webhook      │
                  │  • assignms  │    │   secret)      │
                  │  • roster    │    └────────────────┘
                  │  • repos     │
                  │  • sessions  │
                  └──────────────┘
```

- **Hosting**: GCP, separate project from Eval, same Delquillan org.
- **Compute**: Cloud Run (scale-to-zero). One service, Next.js App Router serving both UI and API routes.
- **Database**: Cloud SQL Postgres (own instance — not shared with Eval).
- **Secrets**: Secret Manager for App private key and webhook secret. App private key fetched at boot, used to sign JWTs in memory.
- **Auth**: Sign in with GitHub via the App's OAuth (user-to-server). No Identity Platform.
- **Deploy**: GitHub Actions → container → Artifact Registry → `gcloud run deploy`.

---

## Data model (sketch)

Multi-tenant from day one. `installation_id` denormalized on relevant tables for query speed and easy RLS predicates.

```
users
  id (pk, internal)
  github_user_id (unique)
  github_login
  created_at

installations
  id (pk = github installation_id)
  owner_type ('user' | 'organization')
  owner_login
  owner_id (github account id)
  installed_by_user_id (fk users)
  suspended_at (nullable)
  created_at

sessions
  id (pk)
  user_id (fk users)
  current_installation_id (fk installations, nullable)
  expires_at

courses
  id (pk)
  installation_id (fk installations)
  name
  slug                              -- used in repo naming
  created_at

assignments
  id (pk)
  course_id (fk courses)
  installation_id (denormalized)
  name
  slug                              -- used in repo naming
  template_repo_full_name
  closes_at (nullable)              -- display-only in v1
  created_at

roster_entries
  id (pk)
  course_id (fk courses)
  installation_id (denormalized)
  external_identity                 -- name/student_id from CSV
  external_id (nullable)            -- optional pre-known student_id
  github_user_id (nullable)         -- populated on first accept
  created_at

student_repos
  id (pk)
  assignment_id (fk assignments)
  roster_entry_id (fk roster_entries)
  installation_id (denormalized)
  github_repo_id (unique)
  github_repo_full_name
  accepted_at
  last_push_sha (nullable)
  last_push_at (nullable)
```

### Schema notes

- Every "ownable" row carries `installation_id` either directly or one join away. Denormalized columns are for query speed and clean RLS predicates.
- `courses.slug` + `assignments.slug` + student GitHub handle = repo name: `{course-slug}-{assignment-slug}-{handle}` → `cs101-a3-janedoe`.
- `roster_entries.github_user_id` is null until the student accepts their first assignment; identity-linking on first accept populates it.
- Read-model fields (`accepted_at`, `last_push_sha`, `last_push_at`) are projections from GitHub webhooks. Source of truth is GitHub; this is a rebuildable cache.
- Postgres RLS using session variable `app.installation_id` is encouraged as belt-and-suspenders (same pattern as Eval).

---

## Auth model

### Authentication

"Sign in with GitHub" via the App's OAuth (user-to-server). No Identity Platform, no Firebase Auth, no passwords.

1. User hits dashboard → redirect to GitHub authorize URL (App's OAuth `client_id`).
2. GitHub handles login + consent.
3. Redirect back with code → exchange for user access token → `GET /user` for identity.
4. Upsert `users` row by `github_user_id`.
5. Mint session (DB row keyed on cookie; or signed cookie). Set cookie.
6. Discard the GitHub user token — we don't need to keep it.

For each new session: `GET /user/installations` (using a fresh user token if needed) returns installations the user can manage. Surface as picker if > 1; auto-select if 1; show install link if 0. Cache for session duration.

### Authorization

GitHub answers "who is this." Your roster/installation data answers "what can they do." For v1, the installer is the sole instructor for that installation. Cross-installation data access is forbidden.

### Token storage summary

| Token | Stored? | Lifetime | Notes |
|---|---|---|---|
| App private key | Yes — Secret Manager | Long-lived | One per deployment. Fetched at boot, signs JWTs in memory. |
| Webhook secret | Yes — Secret Manager | Long-lived | One per deployment. Verifies webhook HMAC. |
| Installation ID | Yes — `installations` row | Until uninstall | GitHub's identifier for the install. |
| Installation access token | **No** | 1 hour | Mint on demand from JWT. Cache in memory for TTL. |
| User OAuth token | **No** (long-term) | Short | Use once to read identity + installations, discard. Mint fresh on each new session if needed. |

---

## Key flows

### Instructor: first-time setup

1. Visit dashboard → "Sign in with GitHub".
2. If no installations: prompt to install the App (`github.com/apps/<app-slug>/installations/new`).
3. Install on user account or org. `installation.created` webhook → backend creates `installations` row.
4. Return to dashboard. Installation picker shows the new installation; select it.
5. Create a course (name + slug).
6. Import roster (CSV upload). Minimum CSV column: a display name. Optional: `student_id`, `github_login` (pre-link), `email`.

### Instructor: create assignment

1. In course context, "New Assignment" form.
2. Pick template repo from list (App fetches accessible repos in the installation via API).
3. Set name + slug. Optionally `closes_at` (display only in v1).
4. Submit. Assignment is active; accept URL is `https://<app>/accept/<assignment-id>`.

### Student: accept assignment

1. Click accept link from instructor (Slack/email/LMS).
2. If not signed in: GitHub OAuth (App's `client_id`). One-time authorize screen.
3. Backend resolves student identity:
   - If roster has `github_login` pre-populated and matches → bind directly.
   - Else show "which of these are you?" — list of unlinked roster entries in the course; student picks; backend sets `roster_entries.github_user_id`.
4. Backend creates student repo:
   - `POST /repos/{owner}/{template}/generate` → private repo in installation owner's account, named `{course-slug}-{assignment-slug}-{handle}`.
   - If `.overlay/` exists in template: follow-up commit deleting it (student repo = template minus `.overlay/`).
   - Add student as collaborator with `write`.
5. Success page: link to repo + one-time Codespaces convenience link (`github.com/codespaces/new?repo=<owner>/<repo>`).
6. Backend creates `student_repos` row, sets `accepted_at`.

### Instructor: view assignment

1. Page lists roster entries (left-joined to `student_repos`).
2. Columns: student name, accepted (bool + timestamp), last push (SHA + timestamp), repo link.
3. Optional `?as_of=<ISO datetime>` query param: rewrites each repo link to `tree/<sha>` where `<sha>` is the latest commit on default branch with `committer_date <= as_of`. Resolved per-student via `GET /repos/{owner}/{repo}/commits?until=<date>&per_page=1`. Cache resolved SHAs.
4. The page should be fast: read from the projection in one query. Never fan out to GitHub on page load. This is the central felt differentiator from Classroom.

---

## GitHub App configuration

Registration is one-per-deployment. Self-deployers register their own at `github.com/settings/apps/new`. Verify exact permission names against current GitHub docs at implementation time — names have shifted historically.

### Permissions needed (functional)

- **Repository administration**: create repos, manage collaborators, manage branch protection (v1.1).
- **Repository contents**: read templates, commit overlay-deletion, future devcontainer ops if ever needed.
- **Repository metadata**: read (required default).
- **Repository pull requests**: read (v1.1 feedback features).
- **Organization members**: read (roster pre-linking via org membership).

### Webhook events

- `installation` (created, deleted, suspend, unsuspend) — manage `installations` rows.
- `installation_repositories` — track repo access changes.
- `push` — update `student_repos.last_push_*`.
- (v1.1) `workflow_run` — autograde results.

### Webhook delivery

Single URL on the Cloud Run service: `/api/github/webhooks`. Verify HMAC signature with webhook secret on every delivery. Respond < 10s (GitHub's retry threshold). Heavy work goes to background processing if needed (not anticipated for v1 — webhook handlers should be small DB updates).

---

## Multi-tenancy

- Installation = tenant. Every domain row carries `installation_id` (direct or denormalized).
- Query-level scoping: all queries filter by current `installation_id` from session context.
- Optional row-level security: Postgres RLS using session variable `app.installation_id`, same pattern as Eval.
- Self-deploy = one installation row. Hosted = many.
- Cross-installation data access is forbidden in v1.
- **One instructor → many installations** is the common case (instructor with several course-orgs). Per-installation context in the UI (GitHub-style "you're in this org now"), not cross-installation unified view.

---

## Self-deploy

The hosted instance is just one deployment of a self-hostable application. There is no hosted-only code path; **self-deploy is the design baseline**, whether the deployment runs the published reference image, a local build, or a fork. Everything in this section applies equally to all of them.

### Code-level requirements

1. **All configuration via environment variables.** No hardcoded project IDs, region names, domains, service account emails. The container runs the same image regardless of where it's deployed.

2. **Cloud touchpoints behind small abstractions** with env-var defaults that work everywhere:
   - **Secrets**: env-var implementation by default. Optional Secret Manager / Vault / AWS Secrets Manager adapters selected via `SECRETS_PROVIDER` (default `env`). The hosted instance uses `gcp`; self-deployers default to `env`.
   - **Scheduler** (v1.1, for deadline enforcement): in-process cron by default. Optional external scheduler hitting a wakeup endpoint.
   - **Logging**: stdout/stderr only, structured JSON. No SDK-based log shipping. Operators ship logs however they prefer.

3. **Database migrations as a first-class command.**
   - Single command brings the schema to current (`npm run migrate` or equivalent). Idempotent across any prior version.
   - Optional startup migration via `RUN_MIGRATIONS_ON_STARTUP=true`.
   - No manual SQL ever required for setup or upgrade.

4. **Container image as build artifact; registry as deployment config.**
   - The repo builds a canonical container image on every release tag via GitHub Actions. The maintainer publishes it to GitHub Container Registry (public, `ghcr.io/jdelfino/handout`) as a reference, tagged with semver (`v1.2.3`, `1.2`, `1`, `latest`).
   - The published image is a convenience, not a coupling. Every deployment recipe takes a container image URI as a config parameter, defaulting to the reference image but always overridable. Forks build their own and point their deploys at their own registries. Air-gapped operators mirror to internal registries. Operators who want to audit before deploying build from source. The hosted instance happens to consume the reference image, but the deployment mechanism doesn't assume it.

5. **Fail-fast configuration validation at startup.** Required env var missing → clear error naming the var, exit non-zero. No partial degradation.

6. **Health check endpoint** at `/healthz` — used by Cloud Run, self-deployers' load balancers, and Docker Compose healthchecks.

7. **HTTP-only** at the application layer. The app speaks plain HTTP and listens on `PORT`. TLS termination is the operator's job (Cloud Run, Fly, Render handle it automatically; VPS deployers front with Caddy/nginx). GitHub does require HTTPS for webhook delivery, so the *exposed* URL must be HTTPS — but that's the proxy's responsibility, not the app's.

### Required env vars

| Var | Purpose |
|---|---|
| `GITHUB_APP_ID` | App ID from registration |
| `GITHUB_APP_PRIVATE_KEY` | PEM contents (or path via `GITHUB_APP_PRIVATE_KEY_PATH`) |
| `GITHUB_APP_CLIENT_ID` | OAuth client ID |
| `GITHUB_APP_CLIENT_SECRET` | OAuth client secret |
| `GITHUB_APP_WEBHOOK_SECRET` | Webhook HMAC verification |
| `DATABASE_URL` | Postgres connection string |
| `SESSION_SECRET` | Session cookie signing |
| `APP_BASE_URL` | Public URL of the instance (e.g. `https://classroom.example.edu`) |

Optional:

| Var | Default | Purpose |
|---|---|---|
| `PORT` | `8080` | Listen port |
| `LOG_LEVEL` | `info` | `debug` / `info` / `warn` / `error` |
| `SECRETS_PROVIDER` | `env` | `env` / `gcp` / `aws` / `vault` |
| `RUN_MIGRATIONS_ON_STARTUP` | `false` | Auto-migrate at boot |

### Deployment artifacts shipped in the repo

- `Dockerfile` — canonical image build. Anyone can `docker build .` and produce an equivalent image.
- `docker-compose.yml` — simplest self-deploy: app + Postgres, `docker compose up` and go. Sensible defaults so ~5 env vars get a working instance. Takes `IMAGE` env var, defaults to the reference image.
- `deploy/terraform/gcp/` — Terraform module for GCP deployment (Cloud Run + Cloud SQL + Secret Manager + IAM + domain mapping). Inputs include `project_id`, `region`, `container_image`, `domain`, `db_tier`, etc. The same module the hosted instance uses, parameterized — fork it, vendor it, or use it directly. Other clouds get their own modules when someone needs them.
- `docs/deploy/` — short per-platform recipes: Docker Compose, Fly.io, Render, generic Linux VPS, and a pointer to the GCP Terraform module. Each recipe (10-30 lines) takes image URI as input.
- `docs/setup/SELF_HOSTING.md` — end-to-end self-hosting walkthrough: GCP project, App registration, configuration, deployment recipes, ongoing operator responsibilities.
- `docs/build.md` — building from source for forkers and audit-from-source operators. Short: `docker build`, push to your registry, point your deploy at it.
- `docs/upgrade.md` — pull new image (or build your fork's new image), run migrations, restart. Idempotent migrations make this safe.

### Stretch goal for v1: GitHub App manifest flow

GitHub supports a manifest-based App registration where the manifest (permissions, webhook URL, callback URL) is described in JSON and posted to GitHub. The UX is:

1. Self-deployer visits `https://<their-instance>/setup` on a fresh deployment.
2. Page renders a "Register GitHub App" form that POSTs a manifest to `github.com/settings/apps/new?state=<token>`.
3. User confirms on GitHub; GitHub creates the App with permissions, callback URL, and webhook URL pre-filled correctly.
4. GitHub redirects to `https://<their-instance>/setup/callback?code=<...>`.
5. The instance exchanges the code for App credentials and writes them to its config store (or echoes them for the operator to put into env vars, depending on deployment style).

This eliminates the most error-prone setup step. Worth shipping for v1 if it fits the timeline; v1.1 otherwise. Either way, the `docs/setup/github-app.md` manual walkthrough is the fallback.

### Operator responsibilities (not the App's)

- Database backups (operator's call — pg_dump cron, managed Postgres snapshots, etc.)
- TLS termination
- Domain and DNS
- Monitoring and alerting beyond the `/healthz` endpoint
- Local-dev tunnel for webhook testing during development (smee.io, ngrok, etc.) — webhooks require a publicly reachable HTTPS URL
- Compliance posture (FERPA, GDPR, etc.) — the App stores only what's needed for the roster; operator decides how that meets their obligations

### License

Apache License 2.0. See [LICENSE](../../LICENSE) and [NOTICE](../../NOTICE).

---

## Design principles

These came out of the design conversation and should drive implementation calls.

1. **GitHub is the source of truth.** Don't duplicate state GitHub owns; project it for read performance.
2. **Read-side projection, not write-side enforcement** wherever possible. Materialize from webhooks into a small read model; dashboard reads in one query.
3. **Webhook-driven freshness with reconciliation backstop.** Webhooks deliver most updates; a periodic sweep catches drops (v1.1 — for v1, accept some drift).
4. **GitHub-native UI over custom UI** where it exists. PR comments, Checks tab, repo views: lean on them.
5. **Functions of time, not state machines.** "View as of" beats persistent deadline state when the goal is grading rather than enforcement.
6. **Single-source-of-truth secrets at deployment level.** Mint per-request tokens on demand; cache in memory only.
7. **Multi-tenant codebase, single-tenant capable.** Self-deploy is one tenant; hosted is many.
8. **GitHub-native portability.** Problem repos and student repos live in GitHub; instructors can leave with their data trivially. Shares `.overlay/` problem repo format with Eval (see `docs/design/PROBLEM_REPOS.md` in github.com/jdelfino/eval).
9. **Common path stays simple regardless of org structure.** Instructors install on user accounts, course-orgs, dept-orgs, jumbled orgs — the App treats all uniformly.

---

## Open questions to settle during build

- **Overlay filtering mechanism**: generate-then-delete (`.overlay/`) vs construct contents directly via contents API. Generate-then-delete is simpler; defaulting there for v1.
- **CSV minimum schema**: just `name`, or require `student_id`? Lean minimal — `name` only required, others optional.
- **Repo slug collisions**: two "Jane Doe"s collide on `cs101-a3-janedoe`. Disambiguate with handle suffix or roster entry ID.
- **Roster mid-semester edits**: re-import overwrites? Manual add/edit screen later? V1: re-import only, with conflict warnings.
- **First-time install UX after redirect from GitHub**: do we have a "welcome / create your first course" page, or drop them into an empty dashboard?
- **Hosted-instance domain**: under delquillan.com subdomain or new domain?

---

## References

- Eval repo: `github.com/jdelfino/eval` — sibling product.
- Eval `.overlay/` spec: `docs/design/PROBLEM_REPOS.md` in eval repo. Shared problem repo format.
- Eval `FUTURE_DESIGN.md`: longer-term assignment lifecycle context.
- Agent workflow conventions: `github.com/jdelfino/agent-workflow`.
- GitHub Classroom sunset: `github.blog/changelog/2026-05-26-github-classroom-sign-ups-are-no-longer-available/`.
- GitHub App docs: `docs.github.com/en/apps`.
