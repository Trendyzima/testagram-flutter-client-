# Testagram Flutter Client

The canonical native Flutter application for Testagram. This repository is intended to replace the Flutter/mobile client currently nested under the legacy XClone frontend. It is not a second backend and it does not own account, post, social-graph, ranking, federation, or media-storage records.

## Six runtime repositories + API contract control plane

- **This repository — Flutter client:** native presentation, navigation, local UX state, device permissions and API transport.
- **Testagram Backend:** canonical Appwrite identity validation, account linking, authorization, profiles, posts, social graph, feed orchestration and public API.
- **Testagram CDN:** media delivery, edge caching and range/HLS transport. Private-media access remains origin-authoritative; the CDN must not turn private storage objects into public URLs.
- **The Algorithm:** private ranking and recommendations. The client never calls it directly.
- **Testagram Data Centre:** deployment, object-storage durability, infrastructure, backups and restore. Storage objects remain private and are not exposed directly by the client.
- **Federated Content:** ActivityPub protocol state and remote delivery. The client never calls it directly.
- **Testagram API:** OpenAPI contracts, private service schemas, event definitions, Dart/TypeScript SDKs, immutable source pins and cross-repository compatibility CI. It is not a runtime service or request-path gateway.

## Hard security boundaries

- Appwrite Client SDK is used only for end-user authentication and session JWT creation.
- All product data operations go through the public Testagram Backend API using an Appwrite JWT.
- Media delivery must use the Testagram CDN and the Backend/CDN authorization contract; do not return direct Appwrite Storage or Instabox object URLs to clients. Private assets must be authorized at the origin and excluded from shared caching unless the origin explicitly marks them public.
- Never connect from Flutter directly to PostgreSQL/Neon, Appwrite databases, private service APIs, queues, object-store credentials, or federation/ranking services.
- Never add Supabase SDKs, Supabase URLs/keys, Edge Function calls, or direct database access.
- Never add Upstash or hosted Redis dependencies.
- The Backend must reject unknown/unlinked Appwrite identities. Do not silently create a canonical account or link by matching email.
- Unsupported API operations must show an explicit unavailable/error state; never fabricate success or substitute empty data for a failed request.

## Configure and run

Install the stable Flutter SDK, then provide environment-specific public endpoints at build/run time:

```sh
flutter create --org com.xclone --project-name app --platforms=android,ios,web .
flutter pub get
flutter analyze
flutter test
flutter run \
  --dart-define=APPWRITE_ENDPOINT=https://cloud.example.test/v1 \
  --dart-define=APPWRITE_PROJECT_ID=YOUR_APPWRITE_PROJECT_ID \
  --dart-define=TESTAGRAM_API_URL=https://api.testagram.site
```

Use your actual Appwrite endpoint and project ID. For local development, use an HTTPS development endpoint or localhost HTTP. Do not commit credentials, signing keys, tokens, or environment-specific production configuration.

## Current implementation status

The Android application ID is generated as `com.xclone.app` to preserve the existing XClone installation identity for a carefully staged upgrade. Keep the release signing key stable; do not ship a production update signed with a temporary CI key.

The initial native foundation includes Appwrite email/password session login, Backend JWT transport, authenticated home-feed retrieval, post creation , loading/error/empty states, and a dark-green Testagram visual foundation. Native Polls list, create, vote and results are now available through the Backend polls API.

This is an expanding migration slice, **not full XClone feature parity or a production release**. The source XClone Flutter app contains 121 Dart files and 214 GoRouter route patterns; the route-by-route parity ledger is in `docs/xclone-route-migration-matrix.md`. The destination intentionally does not copy the legacy monorepo or its dependencies. The native main-feed composer now publishes through the Backend's idempotent `POST /api/social/posts` route. It supports text and optional public-image uploads/attachments through Backend-owned media APIs. Post creation commits before media uploads and attachments; if a later media step fails, the client explicitly reports that the text post was published with incomplete media and attempts to delete unattached uploads. This is a deliberate partial-success flow, not an atomic post-plus-media transaction. It does not establish private-media/CDN authorization readiness, which still requires cross-repository staging tests. Profiles and complete graph flows, messaging/E2EE/calls, stories, video/live/TV, creator tools, commerce/wallet/M-Pesa, moderation/admin, federation UI, offline behavior, accessibility, deep links, push, and full integration tests remain open. Each feature must be implemented against a verified Backend contract before being marked complete.

## Migration acceptance gates

1. Every XClone user-facing route has a native equivalent or an explicitly approved retirement.
2. No Supabase SDK/import/env/URL/Edge Function/database operation remains in the Flutter client.
3. No Upstash/Redis dependency is introduced in the client.
4. All authenticated operations use Appwrite JWTs and Backend authorization.
5. Backend, Algorithm, Data Centre, Federation and CDN integration contracts pass across the six runtime repositories, with API contract-governance checks.
6. `flutter analyze`, `flutter test`, Android debug/release builds and real-device smoke tests pass.
7. Existing XClone data, deep links, app identity/signing and user sessions are migrated safely before retiring the old client.
8. XClone is not deleted or archived until the native client reaches verified feature parity and production cutover is approved.


## Current native migration tranche

The client now talks to verified first-class Backend routes:

- `GET /api/feed/home` — authorized home timeline, Following filter and opaque cursor pagination.
- `GET /api/social/posts/{id}/interaction-summary` — viewer-specific like/repost/bookmark state and counters.
- `POST|DELETE /api/social/posts/{id}/reaction` — reaction lifecycle.
- `POST|DELETE /api/social/posts/{id}/reposts` — repost lifecycle.
- `POST|DELETE /api/social/posts/{id}/bookmarks` — bookmark lifecycle.
- `GET|POST /api/social/posts/{id}/replies` — reply listing and creation.
- `GET /api/search` — people and post discovery.
- `GET|POST|DELETE /api/social/follows...` — follow state and follow/unfollow.
- `GET /api/social/notifications` and `POST /api/social/notifications/{id}/read` — notifications.
- `GET|POST /api/threads` and dedicated thread interaction endpoints — separate thread product surface.

The Flutter client must use Backend-owned Fediverse endpoints for every signed-in interaction; it must never call the Federation private or public protocol API directly and must not request a separate Mastodon password/session. The existing Appwrite session remains the only Testagram login.

The Flutter CI runs `tool/check_dependency_boundary.dart`, which fails if Supabase, Upstash or Redis references are introduced into `lib/`, `test/`, platform/tooling source, `pubspec.yaml`, environment files, or the resolved `pubspec.lock`. Do not weaken or remove this check to make a build pass.

## Explicitly not migrated yet

- Main-feed post publishing: Backend does not currently register a first-class create-post endpoint. The Flutter composer reports this accurately and does not create a thread as a substitute.
- Main-feed media upload and the full legacy media lifecycle remain unported. The Threads composer has a separate image upload-intent/upload/complete/attach flow, with API tests; real-device and production-storage verification remain required.
- Profile read/update, direct messages, voice/video calls, wallet and M-Pesa, TV studio, creator/advertising, admin/moderation and federation: no feature is marked complete merely because a legacy route exists.
