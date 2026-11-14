# Public TV channel cache policy

This is a deliberately narrow extraction from the legacy XClone Flutter app:

- Source: `mobile/lib/features/tv/tv_channel_cache_policy.dart`
- Destination: `lib/features/tv/tv_channel_cache_policy.dart`

Only the pure Dart sanitization, encoding and expiry policy is ported. The legacy `TvPage`, Supabase queries, `SharedPreferences` adapter, live-stream loading, ad service and playback implementation are not copied.

## Safety rules

- Only rows explicitly marked `_sourceType: catalog` can be cached.
- User-owned live streams are excluded.
- Only HTTPS URLs without user-info, fragments, local/private hosts or signed credential query parameters are accepted.
- Cache entries expire after 24 hours, contain at most 250 channels and are bounded to 1 MiB of UTF-8.
- The policy is defensive client-side presentation/storage hygiene, not authorization. Backend authorization remains authoritative.

## Integration boundary

This policy is not wired into a TV screen or persistence adapter. The legacy call site reads Supabase-backed `live_streams` and catalogue data, so none of that code was migrated.

The Backend currently exposes an internal OIDC-protected `GET /internal/tv/catalog` for its GitHub Actions monitor and a public `GET /api/tv/health` health projection. Neither is a public app catalogue contract. Do not call the internal monitor endpoint from the client or invent a public TV route. Wire this policy only after the canonical Backend publishes an authenticated/public catalogue contract with explicit public-catalogue semantics.

No Supabase SDK, URL, key, session state, RPC, database access, migration, Edge Function, generated output, signing file or secret is included.
