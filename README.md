# Handout

A GitHub-native replacement for GitHub Classroom: distribute coding assignments
to students by generating per-student repos from a template, and see what
students are doing — without leaving GitHub.

> **Status:** Pre-alpha. Not yet usable. See
> [`docs/design/KICKSTART.md`](docs/design/KICKSTART.md) for the v1 design.

## What it does (v1)

- Install as a GitHub App on your user account or org.
- Create courses; import a roster from CSV.
- Create assignments from any template repo you control.
- Students accept via OAuth; the App generates their per-student repo
  (private, named `{course}-{assignment}-{handle}`) and links them as a
  collaborator.
- Dashboard shows accept status, last-push timestamp, and repo links across
  the whole roster — including a "view as of `<datetime>`" mode that rewrites
  each link to `tree/<sha>` at the commit-as-of-that-time.

**Not in v1:** autograding, deadline enforcement, hidden tests, feedback UI,
group assignments, LMS/LTI integration. The grading workflow lives in your
template repo; the App stays out of it.

## How it differs from Classroom

- GitHub-native. No data to migrate; no third-party platform to manage.
- Self-hostable by design. The hosted instance is just one deployment of the
  same open-source codebase.
- Better default environments via Codespaces (your template's devcontainer
  becomes the student's).
- Built on what's already there: PR comments, Checks, repo views. The App
  adds the roster layer and the cross-student dashboard.

## Architecture (one paragraph)

Next.js (App Router) on Cloud Run, Postgres on Cloud SQL, GitHub App identity
for both webhooks and OAuth. State is a thin projection of GitHub — webhooks
fill it; reads serve from it. See
[`docs/design/KICKSTART.md`](docs/design/KICKSTART.md) for the full design.

## Self-hosting

Self-deploy is a first-class baseline, not an afterthought. The published
image at `ghcr.io/jdelfino/handout` is a convenience — every deployment
recipe takes a container image URI as a parameter, so forks and air-gapped
operators run their own builds. Deployment recipes (Docker Compose, GCP
Terraform, Fly, Render, generic VPS) land in `docs/deploy/` as they're
written.

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

## Related

- [Eval](https://github.com/jdelfino/eval) — sibling product. Shares the
  `.overlay/` problem-repo format so content authored for one runs in the
  other.
