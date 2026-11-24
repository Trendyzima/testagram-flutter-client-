# Production web deployment

Testagram's existing Cloudflare Pages project `testagram-flutter-web` currently has both production custom domains active:
- `testagram.site`
- `www.testagram.site`

The live apex and www requests both resolve to this Pages project. The `testagram.site/.well-known/webfinger*` Cloudflare Worker route remains separate and continues to own the federation discovery path. Production authentication releases update the existing Pages project's production branch; they do not create a replacement project, detach domains, change DNS, or modify Worker routes.

## Production release path

`Flutter client main` → GitHub Actions (Flutter analyze, widget tests, web build and authentication marker checks) → canonical Backend signup readiness probe → existing Cloudflare Pages project `testagram-flutter-web` production branch `main` → smoke tests against both public domains.

The separate `web-container-release.yml` workflow also builds and publishes an immutable GHCR image for the self-hosted Caddy origin. That image is a separate origin/fallback release; publishing it alone does not update the active Pages custom domains.

## Native authentication boundary

Ordinary Testagram registration uses the existing native email/password API at `https://api.testagram.site/api/auth/signup`. Users register with username, email and password, then verify their email to activate the account. Administrator approval and sensitive identity-evidence review are not prerequisites for ordinary signup or sign-in.

Sensitive identity-evidence applications, private evidence storage, reviewer attribution and two-person approval remain separate workflows. They do not gate ordinary native registration, login, access-token validation or refresh-token rotation.

## Production readiness gate

Before publishing a production web bundle, the release workflow submits a non-mutating signup request with a deliberately short password. It must reach native password validation and return exactly `400 INVALID_PASSWORD`. This proves that the public signup route is live and validation is active; the probe creates no account and sends no email.

A `503 IDENTITY_REVIEW_REQUIRED` response is a failed production readiness check. The release workflow must not accept it or publish a production image/page against that response.

## Release sequence

1. Merge the reviewed Backend native-authentication changes only after required CI and PostgreSQL integration checks pass. Confirm the backend deployment and live signup readiness probe.
2. Merge the reviewed Flutter authentication changes only after Flutter analysis, widget tests, web build, authentication marker checks and container smoke tests pass.
3. The main-branch production Pages workflow verifies the existing project, confirms that its production branch is `main`, confirms both existing custom domains are active, and reruns the canonical Backend signup readiness probe.
4. Deploy the built bundle to the existing Pages production branch. The workflow then verifies the same versioned bundle and the sign-in, sign-up, create-account, forgot-password and reset-password markers on both `testagram.site` and `www.testagram.site`.
5. Verify that the apex federation Worker route remains independently fail-closed until its separate protocol acceptance is complete.
6. Complete the controlled real-account acceptance below. Do not use the non-mutating readiness probe as a substitute for an actual user journey.

A merged PR, preview deployment, successful build or published GHCR image is not by itself proof that the production Pages domains have been updated.

## Production acceptance

Before calling the release ready:

1. Confirm the backend deployment and PostgreSQL migration manifest completed without skipped or bypassed required steps.
2. Confirm the signup readiness probe returns exactly `400 INVALID_PASSWORD`, not `503 IDENTITY_REVIEW_REQUIRED`.
3. Confirm `https://testagram.site/` and `https://www.testagram.site/` serve the same new versioned Flutter release.
4. Confirm direct routes `/?mode=signin`, `/?mode=signup` and `/?mode=forgot` open the intended sign-in, signup and password-recovery screens.
5. Confirm the bundle contains Sign in, Sign up, Create account, Forgot password? and Reset password.
6. Check mobile and desktop layouts and browser console/network errors.
7. In a controlled real-account test, verify signup, OTP/email verification, sign-in, password recovery, session restoration and sign-out. Do not use a fake account, mocked email sender or test-only shortcut.

## Configuration boundary

Only public client configuration belongs in Flutter build variables, including the canonical API origin `https://api.testagram.site`. Never place database credentials, JWT signing secrets, email API tokens, edge proxy tokens, identity-evidence storage credentials or other backend secrets in the Flutter bundle.
