# Testagram hybrid social + knowledge screen system

Status: design and implementation contract; not a claim of shipped UI or backend readiness.

## Product objective

Build one Testagram experience that combines four useful interaction models:
- Quora-like knowledge: questions, substantive answers, topics, answer revisions, accepted answers and contributor context.
- X-like conversation: concise posts, replies, quote posts, reposts, reactions, fast search and live conversation surfaces.
- Bluesky-like discovery: clear Following and Discover lanes, portable identity concepts and user-controlled discovery.
- Mastodon-like agency: chronological timelines, lists, content warnings, muted/blocked controls and transparent federation provenance.

These are interaction references only. Testagram owns its visual identity, code, data model, moderation policy, API and account system. Do not copy logos, names, exact layouts, proprietary assets or distinctive branded styling.

## Navigation information architecture

### Mobile primary navigation
1. Home — default social timeline with For you / Following / Latest lanes.
2. Discover — search, topics, people and curated discovery.
3. Ask — dedicated Questions & Answers hub; a creation action opens the question composer.
4. Notifications — mentions, replies, answer activity, follows and moderation notices.
5. You — profile, posts, answers, saved items, lists and settings.

Use a persistent bottom navigation bar with clear selected states, labels and safe-area handling. Compose is a contextual action, not a sixth destination. The Ask destination must not be linked to a fake local data source: until Backend Q&A routes are merged and deployed, show an explicit unavailable state and do not fabricate question cards or successful submissions.

### Tablet and desktop
Use a three-column social layout at wide breakpoints:
- Left rail: Testagram mark, Home, Discover, Ask, Notifications, Messages (only when backed by a verified API), Bookmarks, Lists, Profile and Settings.
- Centre: active timeline, search results, question detail or profile.
- Right contextual rail: topic suggestions, relevant people, active conversation context and help. Every module must be driven by authorized Backend data; hide modules with no verified endpoint.
At medium widths collapse the left rail to icons and hide the right rail. At mobile use bottom navigation and full-width content.

## Screen specifications

### 1. Home / social timeline
- Header: Testagram identity, account/avatar action and refresh.
- Segmented timeline lanes: For you, Following, Latest. Optional Media and Lists are secondary filters, not permanent top-level tabs.
- Composer: text, media, visibility and content-warning controls supported by verified Backend contracts. Show publishing progress and precise partial-success errors.
- Feed cards: author identity, timestamp, federation origin label when remote, body, media, reply/repost/quote/like/bookmark actions and accessible action counts.
- Pagination uses opaque cursors; refresh resets the cursor. Preserve scroll position when switching lanes where practical.
- Provide distinct loading, empty, offline, authorization, moderation and retry states. Never map API failure to an empty feed.

### 2. Discover
- Search entry with explicit People / Posts / Topics filters.
- Topic directory and topic detail entry points.
- Suggested accounts and public conversation discovery only when returned by Backend.
- Search results show why a result matched where the API provides that information.
- Do not expose remote protocol APIs or call Algorithm directly from Flutter.

### 3. Ask / knowledge hub
- Tabs: For you, Following topics, Unanswered, Answered, Your questions.
- Question card: title, short body excerpt, topic chips, author, answer count, freshness and visibility marker where authorized.
- Question detail: full prompt, topics, author, status, accepted-answer marker, answer list, follow-question action and answer composer.
- Answer detail: author, body, revision history, helpful/endorsement controls only if backed by contract, accepted status and moderation state.
- Answer composer supports preview, draft preservation and clear edit/revision history.
- Question author may accept an answer subject to Backend policy; never let the client infer or locally grant acceptance.
- Questions are not posts and answers are not replies. They can be shared into the social graph only through explicit Backend-supported actions.
- Private/follower-only questions must not leak through search, previews, notifications or cached widgets.

### 4. Notifications
- Filters: All, Mentions, Replies, Answers, Follows, System.
- Unread indicator and mark-read action use Backend-confirmed state.
- Notification deep links must re-check authorization when opened.
- Moderation and security notices are clearly distinguished from social activity.

### 5. Profile
- Header: avatar, display name, handle, bio, verified status only if Backend supplies it, follow state and account privacy.
- Tabs: Posts, Replies, Answers, Media, Likes (only if visibility contract permits).
- Follower/following lists, block/mute controls and report action.
- Keep local and federated identity provenance explicit; do not imply a remote account is a native Testagram account.

### 6. Conversation / post detail
- Parent post, reply tree, quote/repost context and composer.
- Maintain context in long threads; visually distinguish reply depth without making content inaccessible.
- Moderation, deletion, visibility and block rules are enforced by Backend, not hidden client-side heuristics.

### 7. Lists and custom feeds
- User-created lists and list membership only after Backend routes exist.
- Chronological ordering must be available and clearly labeled.
- Feed settings explain whether a lane is chronological or ranked; do not label a lane "For you" unless the ranking service actually supplies it.

### 8. Federation-aware content
- Show source network/provenance for remote items and a clear distinction between local and remote actions.
- Explain unsupported actions rather than silently dropping them.
- All signed-in interactions use the Testagram session and Backend facade. Flutter must not authenticate directly with ActivityPub or AT Protocol services.

### 9. Compose and publishing
- Unified compose entry offers Post, Ask a question and Answer (when opened from a question).
- Each composer has the correct data type and visibility options.
- Idempotency key, upload progress, cancellation, retry and partial-success behavior follow Backend contracts.
- Do not claim an attachment is published until Backend confirms attachment completion.

### 10. Settings, safety and account controls
- Privacy, muted words, blocks, content warnings, media preferences, accessibility, theme, language, federation controls and session management.
- Only expose a control when a corresponding Backend operation exists and its result can be verified.
- Destructive actions require confirmation and clear consequences.

## Visual language

- Preserve Testagram's own blue/aqua palette, typography, iconography and brand mark. Do not clone competitor color systems or logos.
- Use a calm, high-density reading surface: clear hierarchy, comfortable line length, thin separators, restrained cards and consistent spacing.
- Prioritize text readability and author attribution; avoid excessive gradients, shadows and decorative chrome.
- Respect light/dark mode, dynamic text scaling, screen readers, focus order, keyboard navigation and reduced motion.
- Use responsive max-width constraints for desktop reading surfaces; avoid stretching long-form answers across the full monitor width.
- Use consistent empty/loading/error components and accessible semantic labels for all actions.

## Implementation sequence and hard gates

1. Navigation and shared screen primitives; preserve existing routes and state behavior.
2. Home lane refinement using the already implemented home-feed API; verify cursor and lane semantics against Backend.
3. Discover/search and profile surfaces using verified existing endpoints.
4. Notifications and conversation detail polish using existing Backend endpoints.
5. Ask hub and question/answer detail only after Backend question/answer handlers, authorization, visibility, moderation and OpenAPI contracts are implemented and tested.
6. Lists, custom feeds and federation controls only after their Backend contracts exist.
7. Cross-organ staging tests for privacy, blocks, mutes, remote provenance, media authorization and cursor pagination.
8. Flutter analyze, unit/widget tests, Android debug/release builds, web build and physical-device accessibility smoke tests.

## Acceptance checklist

- [ ] Mobile bottom navigation and desktop rail have identical destination semantics.
- [ ] Every destination has loading, empty, error, offline and unauthorized states where applicable.
- [ ] No screen fabricates records or success.
- [ ] Questions and answers remain distinct from posts and replies.
- [ ] Following and Latest are clearly differentiated from ranked For you.
- [ ] Every private item is authorized by Backend on fetch and deep-link open.
- [ ] Remote origin is visible and unsupported federation actions are explained.
- [ ] All signed-in requests use native Testagram authentication and public Backend APIs.
- [ ] Accessibility, responsive layout, dark mode and keyboard navigation pass tests.
- [ ] No Supabase, Appwrite, Xclone, direct database, direct federation or direct Algorithm dependency is introduced.
