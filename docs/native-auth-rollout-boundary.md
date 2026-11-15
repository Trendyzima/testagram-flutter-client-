# Native authentication rollout boundary

This document records why the native authentication client is not yet wired into
the production sign-in gate. Do not switch production authentication to
`TESTAGRAM_AUTH_PROVIDER=native` solely because the login endpoint exists.

## What is implemented in the Backend today

The Backend exposes PostgreSQL-backed routes under `/api/auth` for login,
refresh, logout, logout-all, forgot-password and reset-password. Native access
tokens are short-lived and session-bound; refresh tokens rotate and reuse
detection revokes the token family. Password reset consumes a one-time token,
increments the identity token version and revokes existing sessions.

The Flutter client now has a transport foundation that stores access and
refresh tokens in `flutter_secure_storage`, refreshes before access-token
expiry, clears local credentials after refresh failure, and calls the existing
login, refresh, logout, logout-all, forgot-password and reset-password routes.

## Production blockers that must be resolved before wiring the UI

1. `authRespond` currently returns `IDENTITY_REVIEW_REQUIRED` for signup,
   resend-verification and verify-email. The new client intentionally does not
   pretend those routes are operational.
2. The identity application/provisioning schema still contains Appwrite user
   identifiers and Appwrite-specific provisioning states. The two-person
   review process must be migrated to a provider-neutral canonical identity
   transaction before the Appwrite SDK can be removed.
3. Native auth identity UUIDs must be reconciled to existing canonical
   `testagram_local.accounts.user_id` values. A successful password check alone
   must never create a new social identity or bypass identity approval.
4. The profile endpoint must reject a valid native session whose subject has no
   active canonical account mapping. This must be verified with integration
   tests before the client treats login as complete.
5. The existing email-verification pipeline needs a provider-neutral,
   single-use token flow. Existing verified-email evidence must be preserved;
   it must not be inferred from an email address match.
6. The deployment must configure the existing Backend authentication issuer
   secret and SMTP settings, apply the auth/session migrations, and pass
   rollback and account-preservation acceptance tests before switching providers.

## Video authorization boundary

The video API must not retain Appwrite credentials or either video-specific
signing variable (`VIDEO_SIGNING_SECRET` or
`VIDEO_PLAYBACK_SIGNING_KEY`). Playback authorization must be delegated to
the Backend's canonical account/session boundary. The video service must not
accept caller-supplied user IDs or trust a client-generated identity claim.
Private HLS manifests, child playlists, segments and encryption keys must all
be authorized; protecting only the manifest is insufficient.

## Release rule

This work is a staged migration. Keep the native client transport isolated
until the canonical identity mapping and review pipeline are provider-neutral.
Do not remove the existing production authentication provider, flip the
provider feature flag, or deploy this client transport before those gates pass.
