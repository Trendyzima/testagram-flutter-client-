# Authentication and media service circuit

This document records the production trust boundaries for the Flutter authentication and media flows.

> **Readiness note:** this describes the intended and source-implemented trust path, not a claim that all production providers are currently enabled or passing live acceptance. Backend deployment defaults keep media replication and public identity registration disabled until provider credentials, migrations, policy versions and live acceptance gates are verified.

## Ownership and request path

1. **Cloudflare Pages** serves the Flutter web bundle and the approved HTTPS callback origin. It is a frontend host, not an identity or product-data authority.
2. **Appwrite Auth** owns email/password credentials, sessions, email verification and password recovery. Flutter creates an Appwrite session and obtains a short-lived Appwrite JWT; no Appwrite API key or server credential is shipped in the client.
3. **Testagram Backend on the Instabox VPS** validates the Appwrite JWT, resolves the Appwrite user ID to the canonical Testagram account UUID, and owns product authorization and APIs. Flutter must not treat an Appwrite session alone as permission to enter the feed.
4. **PostgreSQL** stores canonical accounts, identity mappings, profiles, posts and media metadata. The client never connects to it.
5. **Private identity evidence** travels from Flutter to the authenticated Backend upload route. The Backend validates content type, size and SHA-256, stores it in the private evidence namespace, verifies the upload, and requires successful replication before the evidence is accepted for review.
6. **Instabox VPS storage, Cloudflare R2 and Backblaze B2** are server-side storage providers. They are never called directly by Flutter and their credentials must never enter the web or Android build.
7. **Testagram CDN behind Cloudflare** delivers media bytes under Backend-controlled visibility and authorization. The CDN is not an identity authority and must not bypass Backend policy with direct public R2/B2 fallbacks.

## Sign-in acceptance

A successful product sign-in requires all of the following:

- Appwrite accepts the email/password credentials and reports the email as verified.
- Flutter obtains an Appwrite session JWT.
- The Backend validates that JWT against Appwrite and resolves an existing Appwrite-to-canonical mapping created by the approved provisioning saga.
- The associated provisioning record is completed and the identity application has reached the verified state.
- Only then does Flutter open the authenticated application shell.

A persisted Appwrite session is checked against the Backend again at app startup. A valid Appwrite session by itself is not a Testagram account. Missing approval, a missing canonical mapping, an inactive account or an unverified email keeps product APIs and the authenticated shell locked.

## Registration acceptance

Registration is an identity application first; Appwrite account creation is deliberately delayed until approval:

1. Flutter collects the applicant's name, desired username, email, 18+ declaration and acceptance of the current Terms and Privacy versions.
2. Flutter creates a pre-authentication identity application with a 256-bit random idempotency key. The Backend records the versioned consent evidence and issues an applicant-scoped application token and age-assurance session token.
3. The applicant uploads private evidence through the Backend proxy. The Backend validates type, size and SHA-256 and requires the private evidence to be verified across the configured storage providers before it enters manual review.
4. Two independent reviewers record the required matching review decisions. A separate two-person account-approval action must then be completed; one reviewer cannot approve their own application.
5. Only after both approval stages does Flutter create the Appwrite credential account, obtain an Appwrite session and redeem the short-lived provisioning authorization.
6. The Backend transactionally creates the canonical PostgreSQL account, Appwrite mapping and completed provisioning record. If email verification is still pending, the account remains blocked from product APIs until Appwrite confirms verification.
7. Repeat provisioning attempts must resolve to the same canonical account; they must not create duplicate accounts or consume a second approval.

Direct Appwrite account creation is not an alternate registration route. An Appwrite user without the approved provisioning mapping cannot access Testagram product APIs, even with a valid and verified Appwrite session.

## Media acceptance

- Public image upload uses the Backend's authenticated upload-intent, upload and completion APIs. The Backend controls provider placement, checksum verification, replication and media ownership.
- Private identity evidence uses a separate private namespace and reviewer authorization path. It must never be exposed through public CDN delivery.
- A post may only attach media after the Backend confirms the asset is in an allowed ready state. A pending replica is not a successful upload.
- Cloudflare caching must respect Backend visibility. Do not add direct R2/B2/MinIO delivery fallbacks to Flutter.

## Production switches and release gates

Both registration gates default to `false` and must remain aligned:

- `TESTAGRAM_IDENTITY_REGISTRATION_ENABLED=false` in the Backend environment.
- `TESTAGRAM_IDENTITY_REGISTRATION_UI_ENABLED=false` in the Flutter build by default. Set it to `true` with `--dart-define` only after the Backend gate is ready.
- `MEDIA_REPLICATION_ENABLED=true` is required for acceptance, with the Instabox storage path and both R2 and B2 private buckets configured and credentials verified.
- `TESTAGRAM_TERMS_VERSION` and `TESTAGRAM_PRIVACY_VERSION` must match the published policy versions in Backend and Flutter builds.
- Appwrite's production platform and verification/recovery callback origins must include the canonical Testagram domains.
- `ONSPACE_AI_API_KEY` and `ONSPACE_AI_BASE_URL` must be configured in the Backend secret environment; post creation fails closed when moderation is unavailable.

Before enabling registration, run a real approved test application through private evidence replication, two independent review decisions, separate two-person account approval, Appwrite account creation, one-time provisioning redemption, email verification, sign-in and canonical profile resolution. Then prove a new authenticated account can create a moderated post, attach only ready media, and read the post back from the feed/CDN path.

Never enable only the frontend flag. If any storage, reviewer, Appwrite, moderation, Backend or callback gate is unavailable, keep registration closed and report the exact failed gate.

## Client security boundary

Flutter may contain only public Appwrite endpoint/project identifiers, the public Backend HTTPS origin and the public site origin. Never embed Appwrite API keys, Instabox API keys, B2/R2 credentials, private service tokens, reviewer credentials, PostgreSQL credentials or object-store signing keys in Dart defines or client bundles.
