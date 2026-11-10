# Flutter migration progress

Last updated: 2026-11-10

## Migrated into the standalone Flutter client

| XClone capability | Flutter implementation | Backend contract |
|---|---|---|
| Home feed | For You / Following, pull-to-refresh, cursor pagination | `GET /api/feed/home` |
| Post reactions | Like / unlike | `POST|DELETE /api/social/posts/{id}/reaction` |
| Reposts | Repost / undo repost | `POST|DELETE /api/social/posts/{id}/reposts` |
| Bookmarks | Save / remove | `POST|DELETE /api/social/posts/{id}/bookmarks` |
| Replies | List and create | `GET|POST /api/social/posts/{id}/replies` |
| Post detail | Privacy-filtered post read and interaction summary | `GET /api/social/posts/{id}`, `GET /api/social/posts/{id}/interaction-summary` |
| Post interaction lists | Likes, reposts and quotes (up to 100 per request) | `GET /api/social/posts/{id}/interactions/{kind}` |
| Interaction counters/state | Per-post viewer state hydration | `GET /api/social/posts/{id}/interaction-summary` |
| Explore/search | Search posts and people | `GET /api/search` |
| Profile detail | Native profile header, avatar, bio, counts, protected-account state, follow/unfollow, paginated followers/following lists and profile posts | `GET /api/social/profiles/{user_id}`, `GET /api/social/profiles/{user_id}/connections`, `GET /api/social/profiles/{user_id}/posts`, `GET|POST|DELETE /api/social/follows...` |
| Follow graph | Follow, unfollow and relationship state from search | `GET|POST|DELETE /api/social/follows...` |
| Notifications | List and mark read | `GET /api/social/notifications`, `POST /api/social/notifications/{id}/read` |
| Threads | Timeline, compose, like, repost, bookmark and public image attachment | `GET|POST /api/threads`, thread interaction routes and media upload-intent/upload/complete/attach |
| Polls | List, create, vote, results and offset pagination | `GET|POST /api/social/polls`, `GET /api/social/polls/{poll_id}`, `POST /api/social/polls/{poll_id}/vote` |
| Wallet | Native balance, recent transaction history, username-based recipient resolution and confirmation-gated KES/USD transfers | `POST /api/capability` with `testagram.wallet.balance`, `testagram.wallet.transactions.list`, `testagram.wallet.recipient.resolve`, `testagram.wallet.transfer` |
| Product styling | Testagram light/dark design tokens and branded background | Local Flutter presentation only |
| Navigation | Native Home, Explore, Alerts, Threads and Polls destinations | Local Flutter presentation only |

Every route above was checked against the Backend router and corresponding handler before the Flutter client was wired to it. Product data and authorization stay in the Backend; Flutter holds only presentation state.

## Source migration scope

The inspected XClone Flutter source contains 121 Dart files and 214 GoRouter route patterns. The full route list and per-route migration state are tracked in `docs/xclone-route-migration-matrix.md`. This destination is a clean native Flutter app; source React/Vite files, Supabase implementation, Upstash/Redis dependencies, database schemas/migrations, Edge Functions, generated platform files, machine state and legacy lockfiles are explicitly excluded by `docs/clean-source-port-policy.md`.

## Deliberate blockers (not silently substituted)

- Main-feed post creation is not exposed as a first-class Backend route in the inspected router. The feed composer therefore reports that publishing is unavailable. It does not write to the separate threads table.
- Main-feed media upload and the full legacy media lifecycle are not yet implemented. Threads has a separate tested image upload-intent/upload/complete/attach implementation; it still needs real-device and production storage verification.
- Profile read is now available as a privacy-aware header and follow-state slice. Profile editing, E2EE messaging, call signaling, M-Pesa top-ups, wallet analytics/savings/scheduled transfers, creator, advertising and admin/moderation remain open. The basic wallet slice is implemented: balance, recent transactions, username resolution and confirmation-gated KES/USD transfers. Same-intent transfer retries reuse their idempotency key while the wallet screen remains alive; durable recovery after app process termination remains a release-hardening task.
- A route/screen is not considered migrated until it calls the correct owning repository, passes authorization and failure tests, and has device verification.

## Forbidden dependency boundary

The client has no Supabase SDK, URL, key, REST endpoint or direct database operation. It has no Upstash or Redis package, URL, credential or fallback. CI runs `tool/check_dependency_boundary.dart` against `lib/`, `test/`, `pubspec.yaml` and the resolved `pubspec.lock`. The check must remain mandatory.

## Release blockers

1. Flutter analyzer and unit/widget tests must pass in GitHub Actions.
2. Android debug/release and web builds must pass.
3. Appwrite JWT identity linking must work for migrated accounts; the Backend must reject unknown/unlinked identities.
4. Verify real account feed, interactions, search, follow, notification and thread workflows.
5. Port the remaining XClone feature domains and their backend contracts.
6. Preserve existing signing identity, data, URLs and deep links during cutover.
7. Do not delete, archive or redirect XClone until feature parity and production cutover are approved.
