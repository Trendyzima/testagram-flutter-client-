# Authentication and media circuit

## User authentication

1. User submits email/password through the Flutter native auth screen.
2. Flutter calls the Testagram Backend `POST /api/auth/login`.
3. Backend verifies the canonical PostgreSQL identity, Argon2id credential (or an explicitly reconciled legacy hash that is upgraded on success), email verification, account status, password-reset state and provisioning status.
4. Backend returns a 15-minute native access JWT and an opaque 30-day refresh token.
5. Flutter keeps the access token in memory and persists only the refresh token using platform secure storage.
6. On app restart or access-token expiry, Flutter refreshes through the Backend. Refresh rotation is atomic; reuse of an old token revokes the family.
7. Flutter validates the session with the Backend profile endpoint before opening the authenticated shell.
8. Password reset consumes a one-time token and revokes prior sessions. Logout/logout-all revoke server-side sessions.

## Registration and email verification

Registration is not a direct sign-up call. Flutter creates an idempotent identity application, uploads evidence through the Backend's bounded private proxy, checks application status, and uses the applicant-scoped verification and resend endpoints. Backend requires two distinct identity reviewers and two distinct account approvers before provisioning. Email verification activates the native account. A visible registration entry does not mean the Backend registration gate is enabled.

## Private-service boundaries

- Data Centre video/notification user routes validate the same native access JWT and recheck live PostgreSQL session/account state. User JWTs are not platform service credentials.
- Data Centre platform routes use their own server-side internal token.
- Federation uses separate direction-specific service bearer credentials; public ActivityPub ingress uses protocol signatures.
- Algorithm accepts only its private Backend service token and ranks an already-authorized candidate set.
- CDN private media uses a short-lived Backend viewer assertion plus a separate CDN origin credential. The raw Flutter user JWT is not forwarded as a CDN origin credential.
- Backend remains the authority for identity, ownership, visibility and viewer authorization.

## Acceptance boundary

Unit/widget tests and mocked HTTP contract tests do not prove live end-to-end behavior. Complete staging acceptance must use a real Backend, PostgreSQL, email transport and Data Centre/CDN paths, then verify Android and web session restore, refresh, logout, recovery, private-media denial and account-state rejection. Production cutover and public registration activation require separate explicit approval.
