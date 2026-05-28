// Receives GitHub App webhook deliveries (push, installation, etc.).
// Implementation lands in follow-up work. See docs/design/KICKSTART.md →
// "GitHub App configuration → Webhook delivery".

export async function POST(_request: Request) {
  return new Response("not implemented", { status: 501 });
}
