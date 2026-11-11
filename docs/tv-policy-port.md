# Reviewed Flutter policy ports from archived XClone

Source inspected: `Trendyzima/XClone-9b4dz1-9b4dz1-8936-20260809tr/mobile` on its archived `main` snapshot.

This port brings across two deterministic Flutter policy modules and their tests:

- `TvChannelCachePolicy`: bounded 24-hour cache for public catalogue entries only; rejects non-HTTPS URLs, URL user-info, signed/credential query parameters, user-owned streams, duplicate IDs and oversized cache payloads.
- TV playback policy: recognizes real web/external/native playback surfaces, prevents stale channel generations from requesting sponsored ads, pauses on app backgrounding, resumes only previously active playback, and validates YouTube video IDs before constructing an external URL.

The files are intentionally decoupled from legacy storage, Supabase, Redis, routing and player dependencies. They do not implement the TV catalogue UI, channel API, playback engine, ad-serving integration or authorization. Those require verified Testagram Backend/Data Centre/CDN contracts and platform-specific integration tests.

No XClone runtime code, credentials, native platform configuration, package manifest or deployment workflow was copied.

## Additional reviewed policy ports

- Platform inbox filters/unread count and safe internal CTA routing. The destination hardens the source path guard against encoded traversal, encoded separators and control characters.
- Team Chat display/input policy. Its role booleans are explicitly presentation hints, never server authorization.
- Moderation appeal/report form guards for bounded reasons, duplicate/busy states and allowed decision values. The Backend must re-check every condition atomically.

These modules are intentionally not wired to screens until their owning Backend routes, DTOs, permissions and failure states are verified. No UI route is marked migrated by the presence of a policy file.

## Full TV screen blocker

The archived `mobile/lib/features/tv/tv_page.dart` directly imports Supabase, invokes the legacy `/functions/v1/tv-catalog` Edge Function, and uses a Supabase-backed sponsored-ad service. That transport and ad integration are explicitly excluded from this clean client. The audited Backend currently has IPTV social actions and TV health reporting, but no verified public catalogue contract. Backend issue [#161](https://github.com/Trendyzima/Testagram-backend-/issues/161) tracks the first-party catalogue API and ownership split. The full screen/player must wait for that contract and the Backend-authorized CDN playback-grant design; do not substitute a direct source-feed or CDN-origin call from Flutter.
