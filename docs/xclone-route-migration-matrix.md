# XClone → standalone Flutter route migration matrix

Source: `Trendyzima/XClone-9b4dz1-9b4dz1-8936-20260809tr/mobile` at the inspected `main` snapshot.
Destination: `Trendyzima/testagram-flutter-client-`.

## Audit baseline

- The source mobile client contains **121 Dart files** under `mobile/lib/`.
- Its GoRouter configuration declares **214 route entries** (214 unique path patterns).
- The destination is deliberately a clean Flutter application, not a copy of the XClone monorepo.
- The destination currently has native authentication plus Home/Feed, Explore, Notifications, Threads and Polls surfaces. The source's remaining route families are not yet feature-parity migrated.
- A route is not counted as migrated merely because a generic page, navigation link or migration notice exists.

## Route status

| Status | Meaning |
|---|---|
| **Ported slice** | A destination screen uses the standalone Appwrite JWT → Testagram Backend API architecture and has relevant tests. This does not imply every sub-route in that domain is complete. |
| **Not ported** | The route exists in the source but does not yet have a verified equivalent in the destination. |
| **Blocked on Backend contract** | The source behavior relies on a direct database/RPC/Edge Function operation for which no matching public Backend route has been verified. |

## Source route inventory

- `/setup` — Not ported
- `/auth` — Ported slice
- `/` — Ported slice
- `/explore` — Ported slice
- `/search` — Not ported
- `/discover` — Not ported
- `/discover/suggested` — Not ported
- `/discover/popular` — Not ported
- `/discover/fediverse` — Not ported
- `/threads` — Ported slice
- `/post/:postId/replies` — Ported slice
- `/post/:postId/likes` — Ported slice
- `/post/:postId/reposts` — Ported slice
- `/post/:postId/quotes` — Ported slice
- `/post/:postId/quote-likes` — Not ported
- `/post/:postId` — Ported slice
- `/communities` — Not ported
- `/c/:name` — Not ported
- `/c/:name/posts` — Not ported
- `/c/:name/members` — Not ported
- `/c/:name/chat` — Not ported
- `/c/:name/events` — Not ported
- `/c/:name/shop` — Not ported
- `/thread/:id` — Not ported
- `/thread/:threadId/replies` — Not ported
- `/tv` — Not ported
- `/channel/:handle` — Not ported
- `/iptv` — Not ported
- `/tv/channels` — Not ported
- `/tv/reels` — Not ported
- `/stream/:streamId` — Not ported
- `/tv/live/:streamId` — Not ported
- `/videos` — Not ported
- `/shorts` — Not ported
- `/videos/watchlater` — Not ported
- `/hashtags` — Not ported
- `/hashtag/:tag` — Not ported
- `/leaderboard` — Not ported
- `/leaderboard/creators` — Not ported
- `/products` — Not ported
- `/marketplace` — Not ported
- `/p/:productId` — Not ported
- `/shop` — Not ported
- `/mall` — Not ported
- `/orders` — Not ported
- `/create-ad` — Not ported
- `/my-ads` — Not ported
- `/ad-analytics` — Not ported
- `/admin/ad-config` — Not ported
- `/admin/ads` — Not ported
- `/admin/ads-management` — Not ported
- `/news` — Not ported
- `/news/:id` — Not ported
- `/history` — Not ported
- `/fediverse` — Not ported
- `/fediverse/feed` — Not ported
- `/fediverse/discover` — Not ported
- `/fediverse/organic-discovery` — Not ported
- `/fediverse/instances` — Not ported
- `/fediverse/mastodon` — Not ported
- `/fediverse/inbox` — Not ported
- `/fediverse/relay` — Not ported
- `/fediverse/analytics` — Not ported
- `/fediverse/identity` — Not ported
- `/fediverse/controls` — Not ported
- `/fediverse/profile` — Not ported
- `/fediverse/profile/posts` — Not ported
- `/fediverse/profile/threads` — Not ported
- `/fediverse/profile/replies` — Not ported
- `/fediverse/profile/media` — Not ported
- `/fediverse/profile/videos` — Not ported
- `/fediverse/profile/podcasts` — Not ported
- `/fediverse/profile/series` — Not ported
- `/fediverse/profile/likes` — Not ported
- `/fediverse/profile/featured` — Not ported
- `/fediverse/profile/tips` — Not ported
- `/fediverse/profile/gifts` — Not ported
- `/fediverse/profile/followers` — Not ported
- `/fediverse/profile/following` — Not ported
- `/fediverse/profile/analytics` — Not ported
- `/spaces` — Not ported
- `/spaces/:id` — Not ported
- `/space-recording/:id` — Not ported
- `/space/:id` — Not ported
- `/space/:id/recordings` — Not ported
- `/start-stream` — Not ported
- `/tv-studio` — Not ported
- `/tv-studio/:streamId` — Not ported
- `/tv-studio/:streamId/guests` — Not ported
- `/creator-studio` — Not ported
- `/creator-studio/:section` — Not ported
- `/notifications` — Ported slice
- `/messages` — Not ported
- `/profile` — Not ported
- `/bookmarks` — Not ported
- `/profile/:username/followers` — Not ported
- `/profile/:username/following` — Not ported
- `/profile/:username/posts` — Not ported
- `/profile/:username/threads` — Not ported
- `/profile/:username/replies` — Not ported
- `/profile/:username/media` — Not ported
- `/profile/:username/videos` — Not ported
- `/profile/:username/likes` — Not ported
- `/profile/:username/podcasts` — Not ported
- `/profile/:username/series` — Not ported
- `/profile/:username/tips` — Not ported
- `/profile/:username/gifts` — Not ported
- `/profile/:username/analytics` — Not ported
- `/profile/:username` — Not ported
- `/settings` — Not ported
- `/settings/account` — Not ported
- `/settings/appearance` — Not ported
- `/settings/connections` — Not ported
- `/settings/notifications` — Not ported
- `/settings/privacy` — Not ported
- `/notification-preferences` — Not ported
- `/ad-performance` — Not ported
- `/admin` — Not ported
- `/admin/ads-review` — Not ported
- `/admin/fraud` — Not ported
- `/admin/governance` — Not ported
- `/admin/identity-verification` — Not ported
- `/admin/overview` — Not ported
- `/admin/platform-revenue` — Not ported
- `/admin/revenue` — Not ported
- `/admin/seo` — Not ported
- `/admin/staff-recruitment` — Not ported
- `/admin/users` — Not ported
- `/admin/verifications` — Not ported
- `/ai` — Not ported
- `/ai-bot-setup` — Not ported
- `/analytics` — Not ported
- `/appeals` — Not ported
- `/blocked` — Not ported
- `/boost-analytics/:postId` — Not ported
- `/boost-create` — Not ported
- `/call/:callId` — Not ported
- `/challenge/:id` — Not ported
- `/credits` — Not ported
- `/daily-rewards` — Not ported
- `/fraud-detection` — Not ported
- `/help` — Not ported
- `/interests` — Not ported
- `/jobs` — Not ported
- `/leaderboard/challenges` — Not ported
- `/lists` — Not ported
- `/lists/:id` — Not ported
- `/monetization` — Not ported
- `/payouts` — Not ported
- `/platform-inbox` — Not ported
- `/podcasts/analytics` — Not ported
- `/podcasts/search` — Not ported
- `/policy` — Not ported
- `/polls` — Ported slice
- `/post-analytics` — Not ported
- `/post-analytics/:postId` — Not ported
- `/post-remote` — Not ported
- `/post-remote/likes` — Not ported
- `/post-remote/quotes` — Not ported
- `/post-remote/replies` — Not ported
- `/post-remote/reply/:replyId` — Not ported
- `/post-remote/reposts` — Not ported
- `/post/:postId/quote` — Not ported
- `/post/:postId/reply/:replyId` — Not ported
- `/premium` — Not ported
- `/privacy` — Not ported
- `/profile-features` — Not ported
- `/referral` — Not ported
- `/referrals` — Not ported
- `/regulator` — Not ported
- `/regulator/analytics` — Not ported
- `/regulator/announce` — Not ported
- `/regulator/audit` — Not ported
- `/regulator/employees` — Not ported
- `/regulator/features` — Not ported
- `/regulator/moderation` — Not ported
- `/regulator/platform` — Not ported
- `/regulator/reports` — Not ported
- `/regulator/wallets` — Not ported
- `/revenue-analytics` — Not ported
- `/rewards` — Not ported
- `/ride` — Not ported
- `/scheduled` — Not ported
- `/seller/:username` — Not ported
- `/series` — Not ported
- `/sessions` — Not ported
- `/sports` — Not ported
- `/staff` — Not ported
- `/story-analytics` — Not ported
- `/team-chat` — Not ported
- `/terms` — Not ported
- `/thread/:threadId/likes` — Not ported
- `/thread/:threadId/quote-likes/:quoteId` — Not ported
- `/thread/:threadId/quotes` — Not ported
- `/thread/:threadId/reply-likes/:replyId` — Not ported
- `/thread/:threadId/reposts` — Not ported
- `/threads/create` — Not ported
- `/trending/:topic` — Not ported
- `/verify` — Not ported
- `/verify-identity` — Not ported
- `/wallet` — Not ported
- `/wallet/analytics` — Not ported
- `/wallet/converter` — Not ported
- `/wallet/history` — Not ported
- `/wallet/mpesa` — Not ported
- `/wallet/pocket` — Not ported
- `/wallet/receive` — Not ported
- `/wallet/referrals` — Not ported
- `/wallet/reminders` — Not ported
- `/wallet/savings` — Not ported
- `/wallet/scheduled` — Not ported
- `/wallet/security` — Not ported
- `/wallet/send` — Not ported
- `/wishlist` — Not ported

## Domain-level parity

| Domain | Source modules | Destination status |
|---|---|---|
| Authentication, recovery, legal acceptance, session lifecycle | `features/auth`, `core/auth` | Ported slice: Appwrite session/JWT foundation; source Supabase PKCE/session implementation excluded |
| Home feed, post details, replies, reactions, reposts, bookmarks, quotes | `features/feed`, `features/posts` | Ported slice: read feed, native post detail, replies, reactions, reposts, bookmarks, and likes/reposts/quotes lists; post publishing and quote creation remain open |
| Threads | `features/threads` | Ported slice: timeline, composer, interactions and image attachment |
| Explore, search, follow graph, trends, hashtags, sports | `features/explore`, `features/discovery` | Ported slice: search and follow basics; all secondary discovery routes remain open |
| Notifications | `features/notifications` | Ported slice: list and mark read; preferences, realtime and push remain open |
| Profiles, followers, profile sections, privacy, lists, blocks, mutes | `features/profile`, `features/social`, `features/settings` | Not ported beyond follow state exposed by Explore |
| Direct messages, platform inbox, team chat, calls | `features/messages` | Blocked on verified messaging/E2EE/call contracts |
| TV, IPTV, video, shorts, studio, live spaces | `features/tv`, `features/videos`, `features/spaces` | Not ported; do not copy source playback/catalog services without contract and rights review |
| Communities, challenges, polls, events | `features/communities`, `features/challenges`, `features/social` | Not ported |
| Marketplace, storefronts, orders, wishlist, wallet, M-Pesa, credits, premium | `features/marketplace`, `features/wallet`, `features/commerce` | Blocked on verified commerce/payment contracts |
| Creator, podcasts, series, analytics, referrals, rewards, advertising | `features/creator`, `features/ads` | Not ported |
| Moderation, appeals, verification, admin, regulator, SEO tools | `features/moderation`, `features/admin` | Not ported; requires role-scoped Backend contracts |
| Fediverse | `features/fediverse` | Not ported; Federation service remains behind Backend-owned client contracts |
| News | `features/news` | Not ported |
| Accessibility, offline, deep links, localization, release identity | `core`, platform and test modules | Partial; verify each separately |

## Migration rules

1. Port behavior and presentation; **never port the source Supabase data-access code**.
2. Every data operation must use a typed destination API method backed by a verified public Testagram Backend route.
3. Appwrite is only the identity/session provider. Flutter must not access Appwrite Databases or Storage for product data.
4. Do not introduce Supabase, Upstash, Redis, direct PostgreSQL, service-role credentials, private service URLs, or copied Edge Function clients.
5. Do not invent API routes, return fake success, or replace failed requests with empty data. Show a clear unsupported/error state until the owning Backend contract exists.
6. Port pure presentation widgets and deterministic policy code only after checking their transitive imports. Rewrite source tests that depend on Supabase fixtures or database semantics.
7. Each migrated route must have loading, empty, retry, timeout, offline, authorization and permission states as applicable, plus tests and Android/web builds.

## Cutover

XClone remains the source of truth and fallback during migration. Do not delete, archive, redirect, or overwrite it. Retire it only after all routes are migrated or explicitly approved for retirement and production data/session/deep-link/signing cutover is verified.
