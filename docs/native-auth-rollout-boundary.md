# Native authentication rollout boundary

This document describes the current staged Testagram-owned authentication path.
The Flutter branch and Backend pull requests are not production deployments.

## Implemented in the Flutter native-auth branch

- The application entry point and AuthGate restore sessions through the
  Testagram Backend; they no longer construct an Appwrite client or account.
- The native client persists only the rotating refresh token in secure storage.
  Access tokens remain in memory. A 401 causes one coordinated refresh and
  retry for BackendApi and video interactions.
- Sign-in, password recovery, password reset, logout and session restoration
  use Testagram-owned endpoints.
- Identity application creation, evidence upload and review-status retrieval
  continue to use the existing application-scoped workflow.
- Approved applicants submit a native password to the Backend redemption
  endpoint. Flutter no longer creates an Appwrite account or obtains an
  Appwrite JWT for provisioning.
- Email verification and resend use application-scoped Testagram endpoints.
  The saved application capability is retained until the account is active.
- The Appwrite Flutter SDK and its obsolete web-auth override have been
  removed from this branch.

## Backend implementation and remaining work

Backend PR #294 supplies Argon2id password storage with legacy PBKDF2
verification and lazy upgrade. Backend PR #296 adds native approved-identity
provisioning, hashed one-time email verification and a PostgreSQL provisioning
ledger. PR #296 is stacked on #294; both remain draft and unmerged.

The redemption transaction checks the evidence-review ledger and the separate
two-person account-approval ledger. It creates one native identity and one
canonical profile, consumes the approval grant, and leaves the identity unable
to obtain a session until email verification activates the provisioning row.
Ordinary public signup remains fail-closed.

The following are not yet complete:

1. Staff reviewer authentication and staff-role grants still use Appwrite
   identifiers in the review and sensitive-action ledgers. Preserve the
   historical audit trail while introducing native staff principals and
   two-person authorization for staff-role activation.
2. Remove the remaining Backend Appwrite login bridges, provider adapters,
   callback routes and unused Appwrite configuration only after the native
   staff workflow and account reconciliation are proven.
3. Audit every Flutter API/media client and every Backend route for legacy
   bearer/JWT assumptions. Video likes and comments now use native access
   tokens, but the separate video service still needs its own end-to-end
   authorization acceptance.
4. Run PostgreSQL migration ordering and idempotency, concurrent redemption,
   email-token replay, account disablement, session refresh, Android and Web
   builds, widget tests and end-to-end feed acceptance.
5. Reconcile existing Appwrite users to canonical Testagram UUIDs using
   explicit evidence and controlled account-preservation rules. Never link
   accounts on email equality alone.
6. Configure native auth issuer secrets and email delivery only after the
   reviewed migrations and release gates pass. Do not switch the production
   provider or deploy from these draft branches.

## Video authorization boundary

The Flutter video client uses the same Testagram native access-token provider
as BackendApi and performs at most one refresh/retry after a 401. Playback
authorization remains a separate service boundary: the video service must not
accept caller-supplied user IDs or trust client-generated identity claims.
Private manifests, child playlists, segments and encryption keys must all be
authorized by the Backend-issued capability/session boundary.

## Release rule

This is a staged migration. Keep production authentication and infrastructure
unchanged until the first approved applicant can verify email, sign in with
Testagram-owned credentials, restore and rotate a session, and reach the
authenticated Testagram feed on Android and Web with no Appwrite dependency in
that user path. Staff authorization, legacy-account reconciliation and all
release tests must also pass before declaring Appwrite fully retired.
