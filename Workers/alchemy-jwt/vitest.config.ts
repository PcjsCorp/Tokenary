import { cloudflareTest } from "@cloudflare/vitest-pool-workers";
import { defineConfig } from "vitest/config";

process.env.ALCHEMY_JWT_PRIVATE_KEY = "test-only-unused";
process.env.ALCHEMY_JWT_REQUEST_PROOF_KEY =
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";

export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: {
        configPath: "./wrangler.jsonc",
      },
    }),
  ],
});
