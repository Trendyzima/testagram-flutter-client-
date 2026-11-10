# Production web deployment (GitHub Actions + Cloudflare Pages)

Vercel is not part of the deployment path. The canonical production flow is:

`main` → GitHub Actions (validate, analyze, test, build) → Cloudflare Pages → `testagram.site`.

## GitHub configuration

Create a GitHub Actions environment named `production` and configure:

**Repository/environment variables** (public client configuration; these are compiled into the Flutter web bundle):
- `APPWRITE_ENDPOINT`: the real HTTPS Appwrite endpoint, including `/v1`.
- `APPWRITE_PROJECT_ID`: the Appwrite project ID.
- `TESTAGRAM_API_URL`: the production Testagram Backend HTTPS origin, e.g. `https://api.testagram.site` only if that is the actual deployed API host.

**Environment secrets**:
- `CLOUDFLARE_API_TOKEN`: scoped to the correct account with Cloudflare Pages project read/write/deploy permissions.
- `CLOUDFLARE_ACCOUNT_ID`: the Cloudflare account ID (not a secret cryptographically, but stored here for convenience).

Do not put Appwrite API keys, server keys, database credentials, signing keys or backend secrets into Flutter build variables. Appwrite endpoint and project ID are public identifiers; authentication still depends on Appwrite's client-side session and backend authorization.

## Cloudflare Pages

The workflow creates the Pages project `testagram-flutter-web` on first deployment, with production branch `main`, then deploys `build/web`. Cloudflare Pages serves the static app and provides CDN/TLS.

After the first successful deployment, attach `testagram.site` (and optionally `www.testagram.site`) in Cloudflare Dashboard → Workers & Pages → `testagram-flutter-web` → Custom domains. Keep the existing Cloudflare zone and nameservers; do not change nameservers. If Cloudflare asks to add a DNS record, follow the Pages custom-domain flow for the existing zone rather than replacing nameservers.

## Authentication and API readiness

Before enabling the live domain:
1. Confirm the production Appwrite endpoint and project ID.
2. Add `https://testagram.site` and any intended www hostname to the Appwrite project's allowed Web platforms/origins.
3. Confirm the Testagram Backend accepts the Appwrite project/session JWT and has correct CORS allow-origins for the production web origin.
4. Verify backend health/readiness and the auth/session flow from the deployed Pages URL.
5. Test login, logout, authenticated API requests, refresh/deep-link routing and browser console/network errors.

The workflow deliberately fails if any required configuration is absent and never deploys a build with empty endpoint values. It does not move the live domain automatically. Domain attachment and production cutover happen only after the deployed app is verified.

## Trigger

A push to `main` runs the production pipeline. `workflow_dispatch` can also run it from `main` in the Actions tab.
