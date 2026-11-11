# TV policy port from archived XClone

Source inspected: `Trendyzima/XClone-9b4dz1-9b4dz1-8936-20260809tr/mobile` on its archived `main` snapshot.

This port brings across two deterministic Flutter policy modules and their tests:

- `TvChannelCachePolicy`: bounded 24-hour cache for public catalogue entries only; rejects non-HTTPS URLs, URL user-info, signed/credential query parameters, user-owned streams, duplicate IDs and oversized cache payloads.
- TV playback policy: recognizes real web/external/native playback surfaces, prevents stale channel generations from requesting sponsored ads, pauses on app backgrounding, resumes only previously active playback, and validates YouTube video IDs before constructing an external URL.

The files are intentionally decoupled from legacy storage, Supabase, Redis, routing and player dependencies. They do not implement the TV catalogue UI, channel API, playback engine, ad-serving integration or authorization. Those require verified Testagram Backend/Data Centre/CDN contracts and platform-specific integration tests.

No XClone runtime code, credentials, native platform configuration, package manifest or deployment workflow was copied.
