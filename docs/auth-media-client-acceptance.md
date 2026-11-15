# Flutter authentication and hybrid media acceptance

This is a client integration checklist, not a production identity or media-provider cutover.

## Authentication compatibility

- Appwrite remains the production credential/session provider until the native migration is explicitly approved.
- Flutter obtains Appwrite sessions through the supported SDK and sends the session JWT only to Backend over HTTPS.
- A local Appwrite session alone does not unlock the product shell. Backend must confirm the canonical Testagram UUID mapping and account/provisioning status.
- Never ship Appwrite server API keys, PostgreSQL credentials, MinIO/R2/B2 credentials, Backend service tokens or signing keys in the app.
- Do not use email equality to link identities or silently create replacement accounts.
- On startup and protected API calls, handle revoked, expired, unverified, inactive and unmapped accounts as locked states; do not silently fall back to unauthenticated data.
- Native authentication screens/endpoints remain gated until the Backend migration and API contract are approved. Do not point clients at legacy native endpoints prematurely.

## Session UX acceptance

Test sign-in, app restart, token expiry, SDK reauthentication, logout, account recovery, email verification, device replacement, account deactivation and offline/network failure. Avoid logging tokens or placing them in URLs, analytics or crash reports. Store only supported SDK session state in platform-secure storage.

## Media upload acceptance

1. Client asks Backend for an upload intent using the current authenticated session.
2. Backend determines owner UUID, namespace, visibility, quota, content policy, maximum size and expiry.
3. Client uploads using the short-lived scoped capability; no provider-specific credential or bucket identity is embedded in the app.
4. Client computes SHA-256 incrementally (not by loading very large files into a second full-size in-memory buffer).
5. Client completes the upload with canonical key and declared digest.
6. Client treats the asset as pending until Backend reports verified readiness. A successful HTTP PUT alone is not a ready media asset.
7. Retry is idempotent and must not create duplicate post attachments or bypass quota.
8. Playback uses the canonical Go CDN URL. Private media includes the Backend-issued viewer assertion and must not be converted into a public URL.

## Storage provider boundary

VPS MinIO, Cloudflare R2 and Backblaze B2 are server-side durable copies managed by Backend/Data Centre. Flutter never chooses a physical provider, receives a provider URL as a permanent media identity, or has credentials to read/write/delete buckets. Cloudflare Pages hosts the web bundle only; it is not a storage authority.

## Acceptance matrix

- Upload image and video within namespace limits.
- Reject oversized, unsupported MIME, mismatched checksum and expired upload capability.
- Handle delayed replication and degraded provider state without showing a broken public URL.
- Resume/retry safely after app backgrounding and transient network loss.
- Playback public and private assets with correct visibility behavior.
- Verify HEAD/Range and video seeking on supported devices.
- Delete asset and confirm the UI reflects Backend tombstone state.
- Exercise low-memory Android devices and ensure incremental hashing does not duplicate full video buffers.

No production auth provider, storage provider, public hostname or feature flag is changed by this document.
