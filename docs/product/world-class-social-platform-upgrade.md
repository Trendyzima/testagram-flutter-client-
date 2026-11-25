# World-class Testagram social platform upgrade

Status: product and engineering blueprint with the first pinned-feed implementation in this branch. This document does not claim the remaining roadmap features are shipped.

## Product direction

Testagram should become a creator-first social network where public conversation, short video, knowledge, communities, private messaging, open-network discovery and creator earnings work as one product. The benchmark platforms are references for proven interaction patterns, not templates to copy. Testagram owns its brand, user experience, data model, moderation rules, APIs and monetization.

The defining Testagram advantage should be that a creator can publish once, build a community around the work, host live conversations, earn through transparent KES wallet rails, and keep the resulting audience relationship inside Testagram.

## Existing foundations found in the repositories

The Backend already has native feeds with For You / Following / Latest / Media / Discover modes, list-filtered feeds, ranking metadata, advanced search, hashtag follows, polls, threads, bookmarks, reposts, post views, wallet transfers/tips/Super Chats, M-Pesa top-ups, audio spaces, remote-author subscriptions and ActivityPub/Bluesky feed identities. It owns canonical PostgreSQL data and the public API.

The Flutter app already has Explore, hashtag discovery, a short-video feed, video feed, social lists, polls, threads, knowledge hub, direct messages, calls, creator/podcast analytics, wallet, monetization, notifications and federation-aware post detail. It already has feed lanes and list navigation.

Therefore, the upgrade should extend these capabilities and close integration gaps rather than create duplicate feed, video, poll, wallet, or messaging systems.

## Benchmark findings and Testagram-native adaptations

### Meta: Facebook, Instagram, Threads and Messenger

Useful patterns:
- Facebook Groups and Messenger Communities create persistent spaces around shared interests, rather than relying only on one-to-one follows.
- Facebook Local/Explore brings together relevant posts, groups, events and nearby activity in one discovery surface.
- Instagram Stories, Highlights, Reels and creator insights support lightweight daily publishing, durable profile curation, short video and creator feedback.
- Instagram and Facebook Broadcast Channels support one-to-many creator updates with polls, voice notes, media and optional collaborator participation.
- Threads supports public custom feeds, topic communities, direct/group messaging, fediverse discovery and controls for asking the feed to show more or less of a topic.
- Messenger's message requests and hidden/spam folders reduce unwanted contact without removing private messaging.

Testagram adaptations:
1. **Testagram Communities**: topic-based public/private communities with membership requests, roles, moderators, rules, pinned resources, events, polls and searchable community archives. Use one canonical community membership and moderation model across feed, messages and events.
2. **Creator Broadcast Channels**: one-to-many channels supporting text, media, voice notes, polls, scheduled announcements, collaborator posts and moderation. Followers choose notification intensity and can mute or leave at any time.
3. **Stories and Highlights**: short-lived photo/video/text updates with audience lists, reply controls and profile Highlights. Story visibility must use the same block, privacy and moderation authority as posts.
4. **Unified Discovery**: combine topics, creators, communities, public events and public video in a ranked but explainable Explore surface.
5. **Inbox safety**: message requests, approved-contact rules, spam/hidden folders and creator-focused inbox filters.

### TikTok

Useful patterns:
- A high-retention short-video feed with separate Following and recommendation experiences.
- LIVE Events let viewers discover, register and receive reminders before a stream.
- Multi-Guest LIVE supports co-hosting, moderators, comment filters and audience interaction.
- LIVE Q&A makes questions visible and selectable while a creator is broadcasting.
- Creator subscriptions combine recurring payments, gated content, private communication spaces, member identifiers and custom perks.
- Creator Care Mode and keyword/phrase filtering help creators manage abusive comment volume.
- Smart Split demonstrates how long-form content can be repurposed into multiple short clips.

Testagram adaptations:
1. **Shorts Studio**: improve the existing Shorts experience with draft management, clip trimming, captions, cover selection, chapters, audio levels, upload recovery and post-publish analytics. AI clipping is a later capability that depends on the approved Testagram media-processing stack.
2. **Live Events and Reminders**: schedule a live audio/video event, publish its details, let users register, and send deduplicated reminders through the unified notification engine.
3. **Multi-Guest Live Rooms**: add guest invitations, stage permissions, moderator roles, audience Q&A, comment filters and a clear host handoff model. Reuse existing audio spaces where technically appropriate; do not claim video-live support until the media transport exists.
4. **Creator Memberships**: introduce transparent monthly tiers, member-only posts/media/events, badges and community access. All entitlements and KES settlement must be enforced by Backend, not the client.
5. **Creator Care controls**: per-creator keyword filters, reply limits, trusted moderators and pre-publish policy feedback.

### X

Useful patterns:
- Lists let users build focused timelines around accounts, interests or professional circles.
- Bookmarks provide a private save-for-later space.
- Spaces make live public audio conversation easy to discover.
- Articles support long-form text with rich media and embeds.
- Quote posts and rapid replies support context-rich public debate.

Testagram adaptations:
1. **Pinned Lists**: make a small number of curated lists available as persistent Home shortcuts. The first implementation adds a transactional pin/unpin endpoint with a five-list cap and Flutter controls.
2. **Private Collections**: let users organize bookmarks into named, private collections, with tags and search. Keep bookmarks private by default.
3. **Long-form Publisher**: add article-style publishing with headings, inline media, embeds, drafts and a reading view. Reuse native posts and media references where possible, but keep long-form documents distinct from short posts.
4. **Live conversation discovery**: surface scheduled and active Testagram audio/video rooms in Explore with topic, host and safety context.

### Bluesky

Useful patterns:
- Custom feeds let users choose which algorithm or topic powers a timeline.
- Starter Packs bundle recommended accounts and feeds so new users can quickly find their community.
- Composable moderation labels let users choose whether to show, warn on or hide labeled content.
- Open identity and protocol interoperability make discovery less dependent on one central feed.

Testagram adaptations:
1. **Feed Builder**: users can create, name, pin and share feeds from followed accounts, hashtags, media types and communities. Each feed clearly states whether it is chronological or algorithmically ranked.
2. **Starter Kits**: creators and community moderators can publish curated onboarding packs of accounts, topics, communities and feeds, with share links and QR codes.
3. **User-controlled content labels**: expose transparent labels and per-label show/warn/hide controls. Testagram's safety policy and legal obligations remain authoritative; user controls do not disable required safety enforcement.
4. **Federated identity clarity**: preserve the existing distinction between local, ActivityPub and AT Protocol identities. Remote actions must only appear enabled when a verified Backend handler supports them.

### Mastodon

Useful patterns:
- Independent servers can interoperate through ActivityPub.
- Chronological local, following and federated feeds give people a predictable alternative to algorithmic ranking.
- Content warnings, phrase filters, mute/block and server moderation are first-class controls.
- Public posts can be discovered across servers, while the server remains responsible for what it knows and can safely serve.

Testagram adaptations:
1. **Always-available Latest lane** and a clear chronological mode.
2. **Federated discovery lane** with provenance, origin server and supported-action indicators.
3. **Content warning and phrase-filter controls** shared by local and remote content.
4. **Portable community discovery** without pretending Testagram controls remote servers or remote account enforcement.

### Elk

Useful patterns:
- Multiple account switching.
- Rich text rendering and rich link previews.
- Grouping sequential notifications for the same post.
- Notification controls that let users separately tune likes, boosts and follows.
- Progressive web app behavior and offline-friendly navigation.

Testagram adaptations:
1. **Unified account switcher** with isolated sessions, clear active-account context and safe account switching.
2. **Notification grouping** across likes, reactions, reposts and follows, with category-specific controls. This builds on the unified notification event ledger already being developed.
3. **Rich link cards** with safe metadata fetching, domain reputation checks and explicit media provenance.
4. **Resilient PWA behavior** with safe cached reads and explicit offline/queued states; never claim a write succeeded until Backend confirms it.

## Priority delivery sequence

### Wave 1 — Complete and stabilize foundations
- Finish the unified notification event ledger and real channel dispatch, keeping PR #536 native mail work separate.
- Complete wallet event coverage and add concurrency, replay, retry and recovery tests.
- Fix wallet money arithmetic to integer minor units/decimal-safe operations before financial expansion.
- Complete the pinned-list feature and expose reliable pinned-list state in the Home experience.
- Keep notification, media and messaging delivery asynchronous so wallet/social writes do not depend on delivery-provider availability.

### Wave 2 — Discovery and user control
- Feed Builder with named custom feeds, public/private visibility, pinning and share links.
- Starter Kits for onboarding into accounts, topics, communities and feeds.
- Private bookmark collections.
- User-configurable feed topic controls, chronological mode and explainable ranking metadata.
- Community/topic discovery in Explore.

### Wave 3 — Communities and creator relationships
- Testagram Communities with roles, moderation, rules, membership requests, polls and events.
- Creator Broadcast Channels with collaborator permissions, voice/media/polls and notification controls.
- Safer unified inbox with message requests, hidden/spam folders and creator filters.
- Stories and profile Highlights with strict audience and expiry rules.

### Wave 4 — Live and creator monetization
- Scheduled Live Events, reminders and registration.
- Guest stages, live Q&A, moderation controls and host safety tooling.
- Creator Memberships with recurring KES billing, entitlement checks, refunds/cancellations and ledger-backed settlement.
- Creator analytics for retention, audience conversion, watch time and revenue.
- Repurpose long videos into Shorts only after the native media pipeline supports reliable clipping/transcoding.

### Wave 5 — Open network and platform quality
- Better ActivityPub and AT Protocol provenance, discovery and interoperability.
- Composable content labels and user-level visibility preferences.
- Rich link cards and long-form publishing.
- Multi-account switching and reliable PWA/offline read behavior.
- Accessibility, localization, low-bandwidth mode and Android performance hardening.

## Non-negotiable architecture and safety rules

- PostgreSQL and the Testagram Backend remain canonical for product data, authorization, entitlements, wallet ledger and privacy.
- Flutter calls the public Testagram Backend API; it does not call federation providers or private services directly.
- Preserve existing ownership boundaries across Backend, Data Centre, CDN, Algorithm, Federation and API contracts.
- Do not add Supabase, Xclone, Render, Redis/Valkey, Upstash or a third-party social backend as Testagram runtime dependencies.
- Native Testagram mail remains separate from notification feature work; no external email delivery provider is introduced.
- Wallet balances, tips, memberships and gifts are ledger-backed, idempotent and calculated in integer minor units. Notifications are never the source of financial truth.
- Every new feature needs authorization tests, privacy/block tests, migration tests, pagination tests, abuse/rate-limit controls, observability and Flutter UI tests.
- A feature is not complete because a screen exists. It must have a real Backend contract, durable data model, tests, error states and end-to-end verification.
- No production rollout or merge is implied by this roadmap or by draft pull requests.

## Acceptance definition for "world-class"

Testagram is ready to call a feature production-grade only when:
1. API and Flutter behavior agree on a versioned contract.
2. Database constraints and transactions protect concurrent writes.
3. Privacy, blocking, reporting and moderation are enforced server-side.
4. Retries and duplicate requests are safe.
5. Low-bandwidth Android devices remain usable.
6. Accessibility and localization are covered.
7. CI, PostgreSQL integration tests and relevant end-to-end tests pass.
8. Monitoring can show latency, errors, delivery state and abuse signals.
9. The user can understand and control why content appears and how their data is used.
