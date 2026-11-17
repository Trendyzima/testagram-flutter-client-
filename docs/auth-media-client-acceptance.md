# Native authentication and media client acceptance

This checklist distinguishes source-level tests from live staging acceptance.

## Automated client checks

- Native login request and response parsing.
- Refresh-token storage and access-token memory handling.
- Refresh rotation and 401 retry through the shared Backend client.
- Session restoration and profile validation before the authenticated shell.
- Logout/logout-all success, already-revoked responses and retry behavior when the Backend cannot confirm revocation.
- Anti-enumerating password-recovery response and single-use reset-token handling.
- Identity application idempotency, applicant-scoped status/evidence tokens, email verification and resend contract behavior.
- No direct Flutter calls to Data Centre, CDN origin, Federation or Algorithm private routes.
- No storage-provider credentials, service tokens or raw private origin URLs in the client.

## Required live staging acceptance

1. Sign in with a real, approved, email-verified native test account.
2. Restart the app and confirm session restoration succeeds without prompting for a password.
3. Expire the access token and confirm refresh rotates the opaque refresh token.
4. Replay the old refresh token and confirm the Backend revokes the session family.
5. Sign out and verify the current session is rejected by Backend and Data Centre.
6. Use logout-all and verify every device session is rejected.
7. Request password recovery, receive the real email, reset the password and confirm all old sessions are rejected.
8. Verify an unverified, disabled, pending-provisioning or reset-required account cannot sign in.
9. Complete a staging identity application through private evidence, two independent reviews, two independent approvals, native provisioning and real email verification.
10. Confirm private media is denied without a valid Backend viewer assertion and public media is served only after Backend confirms public/ready visibility.

## Not yet a production claim

The mainline Flutter code uses native auth, but production provider cutover, deployed Backend revision, existing-account reconciliation and full device acceptance must be evidenced separately. Registration stays fail-closed until the storage, email, policy, approval and provisioning gates pass. Do not treat a preview build, mock HTTP test or green unit suite as production authentication acceptance.
