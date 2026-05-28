import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Emit a minimal server bundle at .next/standalone for slim container images.
  // Required by the Dockerfile and any container deployment (Cloud Run, etc.).
  output: "standalone",
};

export default nextConfig;
