# Production web deployment (Flutter web container + InstaBox)

The live web application is served from the immutable Flutter web container on the self-hosted InstaBox origin. Cloudflare provides the public hostname routing and edge layer; Cloudflare Pages is a preview path only and does not publish the production `www` site.

## Canonical production path

`Flutter client main` → GitHub Actions (Flutter analyze, widget tests, release build, container smoke test) → GHCR immutable image `ghcr.io/trendyzima/testagram-web@sha256:...` → Backend repository pins that exact digest in `.github/workflows/instabox-deploy.yml` → InstaBox deploys the web container → Cloudflare-facing `www.testagram.site`.

The apex `testagram.site` redirects ordinary web traffic to `https://www.testagram.site/`. The apex remains the separate federation identity/edge origin. Do not assume a successful Cloudflare Pages preview changes the live site.

## Current safety gate

Public signup must remain fail-closed with HTTP `503 IDENTITY_REVIEW_REQUIRED` until identity evidence review and two-person approval are complete. A visible Create account form is not proof that account creation is available. This monitoring work does not authorize merges, production authentication cutover, deployments, DNS/Cloudflare route changes, or production data changes.

## Release sequence

1. Merge the reviewed Backend migration/authentication change only after all required checks pass. The Backend main-branch deployment must complete its PostgreSQL migration manifest and live `accept-web-authentication` job.
2. While identity evidence review and two-person approval are incomplete, verify that the canonical native signup probe returns exactly `503 IDENTITY_REVIEW_REQUIRED`. This is the required fail-closed state, not proof that signup is available. A `400 INVALID_PASSWORD` is only a future acceptance condition after the evidence and approval requirements are complete and a separate policy change is explicitly authorized.
3. Only after that approval gate is independently verified and a separate release is explicitly authorized may the reviewed Flutter change be merged. Its main-branch workflow analyzes and tests Flutter, compiles the web bundle, checks authentication UI markers, publishes the immutable commit-tagged GHCR image and smoke-tests the published digest.
4. Update the Backend deployment workflow's `TESTAGRAM_WEB_IMAGE` pin to that exact published digest in a separate reviewed Backend change. Merge only after its checks pass.
5. Verify the InstaBox deployment completed and the final `accept-web-authentication` job passed. This is the step that actually updates the live `www.testagram.site` application.
6. Complete the controlled real-account acceptance below.

Do not treat a merged PR, Pages preview, successful build, or published image as a production deployment.

## Native authentication boundary

Public signup uses Testagram's existing native email/password API at `https://api.testagram.site/api/auth/signup`, but the Backend must return `503 IDENTITY_REVIEW_REQUIRED` until identity evidence review and two-person approval are complete. Flutter may display the native account-creation form, but it must never treat this response as success, create a local session, show the email-verification success state, or bypass the Backend gate.

The identity-evidence workflow retains private storage, independent reviewer attribution, historical audit evidence and two-person approval. The native authentication path may provision an account and begin email OTP/verification only after the Backend has verified the required evidence and approvals. A `503 IDENTITY_REVIEW_REQUIRED` response is the required secure state while those prerequisites remain incomplete.

## Production acceptance

Before calling the release ready:

1. Confirm the Backend deployment and PostgreSQL migration manifest completed without skipping or bypassing a required step.
2. While identity evidence review and two-person approval are incomplete, probe the canonical native signup route with a deliberately short password and require exactly `503 IDENTITY_REVIEW_REQUIRED`. This is a non-mutating probe; it must not create an account or send email.
3. Confirm the live `www.testagram.site/` and `www.testagram.site/?mode=signup` routes serve the Flutter shell and the expected versioned application bundle.
4. Confirm the live bundle contains the Sign in, Sign up, Create account, and Reset password flows.
5. Do not create a real test account while the fail-closed gate remains active. Only after identity evidence review and two-person approval are independently verified and a separate production release is explicitly authorized may a controlled test account be created and its OTP/confirmation delivery, email verification and sign-in be tested.
6. Confirm password recovery, resend verification, session restoration and sign-out work from the deployed domain.
7. Check browser console/network errors and responsive behavior on mobile and desktop.

Never use a fake account, mocked email sender, test-only shortcut, or a successful build as a substitute for this end-to-end production acceptance.

## Configuration boundary

Only public client configuration belongs in Flutter build variables, including the canonical API origin `https://api.testagram.site`. Never place database credentials, JWT signing secrets, email API tokens, edge proxy tokens, identity-evidence storage credentials, or other backend secrets in the Flutter bundle.
