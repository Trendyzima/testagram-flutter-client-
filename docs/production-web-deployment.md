# Production web deployment (Flutter web container + InstaBox)

The live web application is served from the immutable Flutter web container on the self-hosted InstaBox origin. Cloudflare provides the public hostname routing and edge layer; Cloudflare Pages is a preview path only and does not publish the production `www` site.

## Canonical production path

`Flutter client main` → GitHub Actions (Flutter analyze, widget tests, release build, container smoke test) → GHCR immutable image `ghcr.io/trendyzima/testagram-web@sha256:...` → Backend repository pins that exact digest in `.github/workflows/instabox-deploy.yml` → InstaBox deploys the web container → Cloudflare-facing `www.testagram.site`.

The apex `testagram.site` redirects ordinary web traffic to `https://www.testagram.site/`. The apex remains the separate federation identity/edge origin. Do not assume a successful Cloudflare Pages preview changes the live site.

## Release controls

- Build and test the Flutter web container from the reviewed Flutter commit.
- Confirm the immutable GHCR image was published and its digest was smoke-tested.
- Update the Backend deployment workflow's `TESTAGRAM_WEB_IMAGE` pin to that exact digest in a reviewed Backend change.
- Merge the Backend change only after its migration, API, deployment-safety and CI checks pass.
- Verify the InstaBox deployment completed and the final `accept-web-authentication` job passed.
- Do not treat a merged PR, Pages preview, successful container build, or published image as a production deployment.

## Native authentication boundary

Ordinary public signup remains fail-closed. The canonical Backend returns `503 IDENTITY_REVIEW_REQUIRED` until the required identity evidence has been reviewed and two-person staff approval is complete. The Flutter client must not treat `IDENTITY_REVIEW_REQUIRED`, `IDENTITY_REVIEW_MFA_UNAVAILABLE`, `REGISTRATION_DISABLED`, or an unavailable evidence service as successful readiness or account creation. After approval, native email/password signup may proceed and email verification is still required before account activation; email verification does not substitute for identity review.

The identity-evidence application and staff-review workflow is the gate for public account creation. Preserve its private-storage, independent-review, historical-audit, and two-person-approval safeguards. Do not substitute email verification for that review or weaken these controls to make signup work.

## Production acceptance

Before calling the release ready:

1. Confirm the Backend deployment and PostgreSQL migration manifest completed without skipping or bypassing a required step.
2. Probe the canonical native signup route with a deliberately short password and require exactly `400 INVALID_PASSWORD`. This is a non-mutating probe; it must not create an account or send email. A `503 IDENTITY_REVIEW_REQUIRED` or `503 IDENTITY_REVIEW_MFA_UNAVAILABLE` response is a release blocker, not readiness.
3. Confirm the live `www.testagram.site/` and `www.testagram.site/?mode=signup` routes serve the Flutter shell and the expected versioned application bundle.
4. Confirm the live bundle contains the Sign in, Sign up, Create account, and Reset password flows.
5. Only after the required identity evidence and two-person approval are complete, create one controlled real test account using an address the operator can access. Verify that the native API accepts it, the OTP/confirmation email is delivered, the code or secure link verifies the account, and the user can sign in.
6. Confirm password recovery, resend verification, session restoration and sign-out work from the deployed domain.
7. Check browser console/network errors and responsive behavior on mobile and desktop.

Never use a fake account, mocked email sender, test-only shortcut, or a successful build as a substitute for this end-to-end production acceptance.

## Configuration boundary

Only public client configuration belongs in Flutter build variables, including the canonical API origin `https://api.testagram.site`. Never place database credentials, JWT signing secrets, email API tokens, edge proxy tokens, identity-evidence storage credentials, or other backend secrets in the Flutter bundle.
