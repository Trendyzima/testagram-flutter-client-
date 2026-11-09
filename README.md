# Testagram Flutter Client

The canonical native Flutter application for Testagram. This repository is intended to replace the Flutter/mobile client currently nested under the legacy XClone frontend. It is not a second backend and it does not own account, post, social-graph, ranking, federation, or media-storage records.

## Five-repository ownership

- **This repository — Flutter client:** native presentation, navigation, local UX state, device permissions and API transport.
- **Testagram Backend:** canonical Appwrite identity validation, account linking, authorization, profiles, posts, social graph, feed orchestration and public API.
- **The Algorithm:** private ranking and recommendations. The client never calls it.
- **Testagram Data Centre:** deployment, object-storage durability, infrastructure, backups and restore.
- **Federated Content:** ActivityPub protocol state and remote delivery. The client never calls it directly.

## Hard security boundaries

- Appwrite Client SDK is used only for end-user authentication and session JWT creation.
- All product data operations go through the public Testagram Backend API using an Appwrite JWT.
- Never connect from Flutter directly to PostgreSQL/Neon, Appwrite databases, private service APIs, queues, object-store credentials, or federation/ranking services.
- Never add Supabase SDKs, Supabase URLs/keys, Edge Function calls, or direct database access.
- Never add Upstash or hosted Redis dependencies.
- The Backend must reject unknown/unlinked Appwrite identities. Do not silently create a canonical account or link by matching email.
- Unsupported API operations must show an explicit unavailable/error state; never fabricate success or substitute empty data for a failed request.

## Configure and run

Install the stable Flutter SDK, then provide environment-specific public endpoints at build/run time:

```sh
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

The initial native foundation includes Appwrite email/password session login, Backend JWT transport, authenticated home-feed retrieval, post creation , loading/error/empty states, and a dark-green Testagram visual foundation.

This is an initial working slice, **not full XClone feature parity or a production release**. Remaining work includes the complete native route/feature inventory, media upload lifecycle, social interactions, profile and graph flows, notifications, messaging, stories, video/live/TV, creator tools, commerce/wallet, moderation/admin, federation UI, offline behavior, accessibility, deep links, push, and full integration tests. Each feature must be implemented against a verified Backend contract before being marked complete.

## Migration acceptance gates

1. Every XClone user-facing route has a native equivalent or an explicitly approved retirement.
2. No Supabase SDK/import/env/URL/Edge Function/database operation remains in the Flutter client.
3. No Upstash/Redis dependency is introduced in the client.
4. All authenticated operations use Appwrite JWTs and Backend authorization.
5. Backend, Algorithm, Data Centre and Federation integration contracts pass across the five repositories.
6. `flutter analyze`, `flutter test`, Android debug/release builds and real-device smoke tests pass.
7. Existing XClone data, deep links, app identity/signing and user sessions are migrated safely before retiring the old client.
8. XClone is not deleted or archived until the native client reaches verified feature parity and production cutover is approved.
