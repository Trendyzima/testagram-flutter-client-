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

Ordinary registration is a direct Testagram-native signup call. Flutter validates email, username, password, age declaration and legal consent, then calls Backend `POST /api/auth/signup`. Backend creates an unverified basic identity and queues a single-use email OTP and link in the same PostgreSQL transaction. The account cannot sign in until the OTP or link is consumed; successful verification initializes the local profile. Identity applications, evidence uploads, independent reviewers and two-person approval are separate optional assurance workflows and never gate ordinary signup.

## Private-service boundaries

- Data Centre video/notification user routes validate the same native access JWT and recheck live PostgreSQL session/account state. User JWTs are not platform service credentials.
- Data Centre platform routes use their own server-side internal token.
- Federation uses separate direction-specific service bearer credentials; public ActivityPub ingress uses protocol signatures.
- Algorithm accepts only its private Backend service token and ranks an already-authorized candidate set.
- CDN private media uses a short-lived Backend viewer assertion plus a separate CDN origin credential. The raw Flutter user JWT is not forwarded as a CDN origin credential.
- Backend remains the authority for identity, ownership, visibility and viewer authorization.

## Acceptance boundary

Unit/widget tests and mocked HTTP contract tests do not prove live end-to-end behavior. Complete staging acceptance must use a real Backend, isolated PostgreSQL, a controlled mailbox and real Flutter signup. Verify initial sign-in denial, real OTP/link delivery and consumption, replay rejection, profile initialization, sign-in, session restore, refresh, logout and password recovery. Continue to verify Data Centre/CDN authorization and account-state rejection. Identity-evidence intake remains independently gated and is not part of the ordinary signup acceptance. Production deployment requires separate explicit approval.
