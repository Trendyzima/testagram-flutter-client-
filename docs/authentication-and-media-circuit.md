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

- Appwrite accepts the email/password credentials.
- Appwrite reports the email as verified.
- Flutter obtains an Appwrite JWT.
- The Backend accepts that JWT and successfully resolves `GET /api/me/profile` to the caller's canonical account.
- Only then does Flutter open the authenticated application shell.

A persisted Appwrite session is checked against the Backend again at app startup. If the Backend is unreachable or the identity mapping is missing, the app keeps the product shell locked and offers retry or sign-out. It must not silently treat an unverified or unlinked identity as an authenticated Testagram account.

## Registration acceptance

Normal self-service registration uses Appwrite directly for credentials and email verification:

- Flutter validates the name, email, password confirmation, adult eligibility and policy acceptance, then creates the Appwrite account with the public Appwrite client SDK.
- Flutter requests the Appwrite email-verification message. The user must redeem the one-time verification link before product access.
- After verification, the user signs in. Flutter obtains an Appwrite JWT and calls the Backend profile endpoint.
- The Backend validates the JWT and transactionally creates the canonical Testagram account and immutable Appwrite-user-ID mapping on first verified sign-in. Repeat sign-ins resolve the same mapping; email equality is never used to claim an existing account.
- If the Backend cannot resolve or provision the canonical profile, Flutter must keep the authenticated product shell locked and show a retryable error.

The separate identity-evidence and two-person approval workflow remains available for any future restricted/high-assurance registration policy. It is not a prerequisite for ordinary self-service accounts and must not be wired as a mandatory gate for the normal Create account action.

## Media acceptance

- Public image upload uses the Backend's authenticated upload-intent, upload and completion APIs. The Backend controls provider placement, checksum verification, replication and media ownership.
- Private identity evidence uses a separate private namespace and reviewer authorization path. It must never be exposed through public CDN delivery.
- A post may only attach media after the Backend confirms the asset is in an allowed ready state. A pending replica is not a successful upload.
- Cloudflare caching must respect Backend visibility. Do not add direct R2/B2/MinIO delivery fallbacks to Flutter.

## Production switches and release gates

The current deployment workflow defaults the separate identity-evidence workflow (`TESTAGRAM_IDENTITY_REGISTRATION_ENABLED`) and `MEDIA_REPLICATION_ENABLED` to `false`. Those switches do not disable Appwrite self-service account creation. Appwrite must still have public account creation enabled, the production project ID and endpoint configured in the Flutter build, and the canonical callback origin registered as a Web platform.

Before enabling public registration, operators must verify in the production environment (without exposing values in logs):

- `TESTAGRAM_IDENTITY_REGISTRATION_ENABLED=true` in the Backend deployment configuration.
- `MEDIA_REPLICATION_ENABLED=true`, with the Instabox storage path and both R2 and B2 private buckets configured and credentials valid.
- `TESTAGRAM_TERMS_VERSION` and `TESTAGRAM_PRIVACY_VERSION` set to the published policy versions.
- `TESTAGRAM_IDENTITY_REGISTRATION_UI_ENABLED=true` in the Cloudflare Pages build configuration.
- Appwrite's production web platform and email verification/recovery callback origins include the canonical Testagram domains.
- A real, approved test application can upload evidence, pass three-provider integrity verification, complete the two-person review, redeem provisioning exactly once, verify email, sign in, and resolve its canonical profile.
- A real authenticated user can upload a media asset, wait for verified replication, publish a post with the ready asset, and read it back through the Backend/CDN path.

Do not enable registration merely by changing a frontend flag. If any storage, reviewer, Appwrite, Backend or callback gate is unavailable, keep registration closed and report the exact failed gate.

## Client security boundary

Flutter may contain only public Appwrite endpoint/project identifiers, the public Backend HTTPS origin and the public site origin. Never embed Appwrite API keys, Instabox API keys, B2/R2 credentials, private service tokens, reviewer credentials, PostgreSQL credentials or object-store signing keys in Dart defines or client bundles.
