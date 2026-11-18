# Native authentication rollout boundary

## Current Flutter source implementation

The current Flutter mainline uses the Testagram-native `NativeAuthClient`. It does not acquire an Appwrite user session.

- Sign-in calls Backend `POST /api/auth/login`.
- Session restoration and token rotation call Backend `POST /api/auth/refresh`.
- Access tokens remain in memory; only the opaque refresh token is stored in platform secure storage.
- `BackendApi` obtains the current access token from the shared auth client and attaches `Authorization: Bearer` to public Backend requests.
- The app validates the restored session through the Backend profile endpoint before rendering the authenticated shell.
- Password recovery/reset uses the Backend's anti-enumerating request and single-use reset-token endpoints.
- Logout and logout-all request Backend revocation before clearing local credentials. If the Backend cannot confirm revocation, the app keeps the session available for retry rather than reporting a false success.

## Registration boundary

The Create your account entry can be visible while public registration remains fail-closed. New accounts must complete the Testagram-owned application, private evidence, two independent identity reviews, two independent account approvals, native provisioning and email verification flow. The Flutter client must not create an account directly or bypass the approval ledger.

## Legacy account migration

Existing Appwrite account IDs are reconciliation inputs only. Appwrite password hashes are not imported; reconciled users must complete native password reset. Do not auto-link by email equality, accept Appwrite JWTs as a native bearer fallback, or disable the legacy production provider until a separately approved migration and live cutover are complete.

## Release boundary

Source code and CI passing do not prove that the deployed Flutter build and Backend are using the same native auth revision. Production API routing, provider cutover, registration activation and real-user account migration remain separate gates. No production deployment or registration enablement is authorized by this document.
