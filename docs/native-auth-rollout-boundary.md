# Native authentication rollout boundary

## Current Flutter source implementation

The current Flutter mainline uses the Testagram-native `NativeAuthClient` and acquires only Testagram-issued user sessions.

- Sign-in calls Backend `POST /api/auth/login`.
- Session restoration and token rotation call Backend `POST /api/auth/refresh`.
- Access tokens remain in memory; only the opaque refresh token is stored in platform secure storage.
- `BackendApi` obtains the current access token from the shared auth client and attaches `Authorization: Bearer` to public Backend requests.
- The app validates the restored session through the Backend profile endpoint before rendering the authenticated shell.
- Password recovery/reset uses the Backend's anti-enumerating request and single-use reset-token endpoints.
- Logout and logout-all request Backend revocation before clearing local credentials. If the Backend cannot confirm revocation, the app keeps the session available for retry rather than reporting a false success.

## Registration boundary

Ordinary self-service registration uses the Testagram-native email/password flow: Flutter calls Backend `POST /api/auth/signup`, Backend creates a basic unverified account and queues a one-time OTP plus verification link, and the user must verify email before sign-in. Identity evidence, staff review and two-person approval are not prerequisites for a basic account. They remain separate, optional assurance controls for capabilities that explicitly require them. The public signup screen must never redirect ordinary users into identity evidence intake or require an identity-application record.

## External identity-provider exclusion

The Flutter runtime has no external identity-provider SDK, login screen, token exchange, hosted auth endpoint, provider session storage or bearer fallback. It authenticates only through the Testagram Backend native login and refresh routes. Do not add a second identity provider or restore a provider-token compatibility path. Account recovery and ownership verification remain Testagram-native.

## Release boundary

Source code and CI passing do not prove that the deployed Flutter build and Backend are using matching native-auth revisions or that a real verification email reaches a mailbox. Require the matching frontend/backend changes, a successful signup readiness probe, and real staging signup-to-verification-to-login acceptance before production activation. Identity-evidence intake remains disabled unless separately authorized after its own WebAuthn and dual-control acceptance. No production deployment or identity-intake activation is authorized by this document.
