# Self-hosting Handout

Work in progress. Steps land here as the project gets there.

## 1. Create a GCP project

```bash
PROJECT_ID="handout-yourname"   # globally unique
gcloud projects create "$PROJECT_ID" --name="Handout"
gcloud config set project "$PROJECT_ID"
gcloud billing projects link "$PROJECT_ID" --billing-account=BILLING_ACCOUNT_ID
```

For reference, the Delquillan-operated hosted instance lives in
`handout-497622`.

## 2. Register a GitHub App

Visit [github.com/settings/apps/new](https://github.com/settings/apps/new)
(personal) or your org's equivalent. Use these settings — they match what
the app will expect once it exists:

- **Homepage URL** — `<your-instance-url>`
- **Callback URL** — `<your-instance-url>/api/auth/github/callback`
- **Webhook URL** — `<your-instance-url>/api/github/webhooks`
- **Webhook secret** — generate one (`openssl rand -hex 32`)
- **Permissions** (Repository unless noted):
  - Administration: Read & write
  - Contents: Read & write
  - Metadata: Read-only
  - Pull requests: Read-only
  - Organization members (Organization perm): Read-only
- **Subscribe to events**: Installation, Installation repositories, Push
- **Where can this be installed**: Any account

After creating: generate a client secret and a private key from the App
page. You'll have App ID, Client ID, Client Secret, Private Key (PEM),
and the Webhook Secret you generated above. Keep them somewhere safe;
they'll feed into the app's configuration once that exists.
