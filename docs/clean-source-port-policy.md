# Clean-source port policy

The canonical destination is this standalone Flutter repository. XClone is a read-only feature/reference source during migration. The goal is to port user-facing Flutter behavior, not transplant the legacy monorepo.

## Explicitly exclude from the destination

- The XClone React/Vite application: `src/`, `public/`, frontend build config, browser-only components and npm lockfiles.
- Backend and infrastructure: API servers, database migrations/schema, SQL, seed data, Edge Functions, serverless functions, workers, queues, deployment manifests, Docker files and environment-specific infrastructure.
- Supabase-specific implementation: `supabase_flutter`, `supabase`, Supabase URL/key configuration, PostgREST query builders, Supabase Storage, Realtime channels, RPC calls and Edge Function invocations.
- Upstash/Redis implementation: SDKs, REST clients, URLs, tokens, cache wrappers, queue clients, rate-limit clients and environment variables.
- Legacy auth/session glue: Supabase PKCE client setup, refresh-token handling, Supabase session storage and policies tied to that token format.
- Generated and machine-specific files: `.dart_tool/`, `build/`, generated platform registrants, local IDE state, caches, temporary exports and machine-local paths.
- The source's `pubspec.yaml` and `pubspec.lock`: dependencies must be reselected for the clean destination, not inherited wholesale.
- The source's Android/iOS/Web platform folders and signing/build configuration: preserve the destination's own package identity, platform configuration and CI; port only reviewed app-specific native permission or capability changes.
- Tests and fixtures whose behavior assumes Supabase tables, RLS, RPCs, Edge Functions, or legacy database schemas.
- Assets that are duplicated, unused, unlicensed, generated, or unrelated to the Testagram product identity.

## Safe port candidates (review each file)

- Pure Flutter presentation widgets and design patterns.
- Deterministic policy/helper code with no backend, storage or platform coupling.
- Media-selection UI and validation policy, rewritten to call the Backend's upload-intent/upload/complete flow.
- Route names, screen behavior and interaction details used as migration requirements.
- Tests rewritten against the standalone Backend API client and mock HTTP contracts.
- Product-owned branding assets after license, usage and duplication review.

## Destination architecture

- Appwrite Client SDK: authentication and JWT acquisition only.
- `BackendApi`: the only public product-data transport. It sends Appwrite JWTs to the Testagram Backend.
- Flutter: presentation, navigation, local transient state, permissions and local/offline UX only.
- Backend: canonical authorization, profile/post/social graph/feed/media/business operations.
- Algorithm, Data Centre and Federation remain private service boundaries; Flutter must not call them directly.

## Mandatory checks before accepting a port

1. Inspect the source screen and all imported helpers, not just its top-level file.
2. Replace every database/RPC/Storage/Realtime/Edge Function call with a verified Backend contract or leave the action explicitly unavailable.
3. Confirm request and response schemas against the Backend router and handler.
4. Check auth, ownership, visibility, role, privacy and rate-limit enforcement server-side.
5. Add tests for success, malformed response, unauthorized, forbidden, timeout, offline and partial failure as relevant.
6. Run the dependency-boundary guard after `flutter pub get`; it scans the resolved lockfile as well as source and config.
7. Run analyzer, unit/widget tests, Android and web builds. Do not mark a feature complete based on route registration alone.

Never weaken the boundary guard to accommodate a copied dependency. Never copy a legacy file and then hide the old data layer behind a renamed wrapper.
