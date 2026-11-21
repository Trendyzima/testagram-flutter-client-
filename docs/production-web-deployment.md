# Production web deployment (GitHub Actions + Cloudflare Pages)

Vercel is not part of the deployment path. The canonical production flow is:

`main` → GitHub Actions (validate, analyze, test, build) → Cloudflare Pages → `testagram.site`.

## GitHub configuration

Create a GitHub Actions environment named `production` and configure:

**Repository/environment variables** (public client configuration; compiled into the Flutter web bundle):
- `TESTAGRAM_API_URL`: the canonical Testagram Backend HTTPS origin. Use `https://api.testagram.site` only after the native Backend origin and public API routes have been independently deployed and verified.

**Environment secrets**:
- `CLOUDFLARE_API_TOKEN`: scoped to the correct account with Cloudflare Pages project read/write/deploy permissions.
- `CLOUDFLARE_ACCOUNT_ID`: the Cloudflare account ID (not a cryptographic secret, but stored here for convenience).

Do not put service tokens, database credentials, signing keys, storage-provider credentials, or backend secrets into Flutter build variables. The client receives only its public API origin; user authentication is performed by the Testagram Backend.

## Cloudflare Pages

The workflow creates the Pages project `testagram-flutter-web` on first deployment, with production branch `main`, then deploys `build/web`. Cloudflare Pages serves the static app and provides CDN/TLS.

After the first successful deployment, attach `testagram.site` (and optionally `www.testagram.site`) in Cloudflare Dashboard → Workers & Pages → `testagram-flutter-web` → Custom domains. Keep the existing Cloudflare zone and nameservers; do not change nameservers. If Cloudflare asks to add a DNS record, follow the Pages custom-domain flow for the existing zone rather than replacing nameservers.

## Native authentication and API readiness

Before enabling the live domain:
1. Verify the canonical Backend deployment is running the reviewed Testagram-native authentication revision.
2. Verify the API origin's health/readiness and protected-route behavior, including rejection of expired, revoked, malformed, and foreign-issuer credentials.
3. Verify registration remains fail-closed until identity evidence, independent review/approval, email verification, staff WebAuthn readiness, and provisioning gates have passed.
4. Exercise login, refresh, session restoration, logout, password recovery/reset, and authenticated API requests from the deployed Pages URL.
5. Test deep-link routing and browser console/network errors.

The workflow must fail if the required API origin is absent or malformed. It does not move the live domain automatically. Domain attachment and production cutover happen only after the deployed app and native Backend have been verified together.

## Trigger

A push to `main` runs the production pipeline. `workflow_dispatch` can also run it from `main` in the Actions tab.
