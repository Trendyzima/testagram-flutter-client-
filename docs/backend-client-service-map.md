# Testagram client ↔ Backend route and service map

This file records the client-side ownership boundary. Keep it synchronized with the Backend router and the testagram-api public contract when routes change.

## Client request ownership

| Client feature | Client implementation | Backend contract |
|---|---|---|
| Signup, verification, login, refresh, logout, password recovery | NativeAuthClient | /api/auth/{signup,resend-verification,verify-email,login,refresh,logout,logout-all,forgot-password,reset-password} |
| Home and feed lanes | BackendApi.getHomeFeed / FeedScreen | GET /api/feed/home |
| Profile, profile posts/media, connections, follow/block | BackendApi / ProfileScreen / ProfileConnectionsScreen | /api/social/profiles/*, /api/social/follows/*, /api/social/blocks/* |
| Follow request moderation | BackendApi / FollowRequestsScreen | testagram.follow_requests.* via POST /api/capability; Backend reuses canonical follow-request handlers |
| Posts, replies, reactions, reposts, bookmarks | BackendApi / post screens | /api/social/posts/* |
| Saved timeline | BackendApi.getBookmarkedPosts / SavedPostsScreen | GET /api/social/bookmarks |
| Lists and pinned lists | BackendApi / list screens | /api/social/lists/* |
| Threads | BackendApi / ThreadsScreen | /api/threads/* |
| Search, trends and hashtags | BackendApi / discovery screens | /api/search, /api/trends/words, /api/hashtags/* |
| Knowledge questions, answers and topics | BackendApi / Knowledge screens | /api/knowledge/* |
| Notifications and preferences | BackendApi / NotificationsScreen | /api/social/notifications*, /api/me/notification-preferences |
| Federation preferences and remote subscriptions | BackendApi / Federation settings | /api/me/federation, /api/federation/subscriptions |
| Wallet and M-Pesa | BackendApi.callCapability / WalletScreen | Backend wallet capabilities; provider callback remains server-to-server |
| Direct messages and one-to-one calls | BackendApi.callCapability / messaging and calls screens | testagram.conversations.*, testagram.messages.*, testagram.calls.* via /api/capability |
| Audio Spaces lifecycle | BackendApi / AudioSpacesScreen | testagram.audio_spaces.* via /api/capability |
| Video | VideoApi / VideoFeedScreen | Dedicated Data Centre video service /v1/*, only through an explicitly configured public HTTPS origin |

The capability gateway is a Backend API contract, not a separate microservice URL. It preserves Backend authentication, authorization, rate limits and canonical data ownership.

## Microservice routing rules

- TESTAGRAM_API_URL points to the public Testagram Backend (https://api.testagram.site by default). The public Caddy route sends this origin to the Backend Go API.
- ALGORITHM_URL is Backend-private (http://algorithm:8092). Flutter must never call the ranker directly; Backend submits an already-authorized candidate set and validates returned IDs.
- FEDERATION_INTERNAL_URL is Backend-private (http://federation-api:8081). Flutter uses Backend federation preference/subscription routes, never Federation's private API.
- Data Centre media lifecycle is Backend-private (http://media:8096 when deployed). Flutter uploads through Backend media intents and receives only authorized upload/playback URLs. Provider credentials and private service tokens never enter the app.
- media.testagram.site is the media delivery plane/CDN, not the product authorization API. Private media still requires Backend-issued access assertions.
- TESTAGRAM_VIDEO_API_URL must be set only when an approved public HTTPS ingress is routed to the Data Centre video service. It intentionally defaults to empty: the current public Caddy configuration routes api.testagram.site to Backend and does not route /v1/videos to the video service. Falling back to the Backend origin would silently send video requests to the wrong service.
- The realtime Worker is not publicly deployed/routed by the current Data Centre contract. One-to-one call signaling and multi-party Spaces media are separate capabilities. Backend Audio Spaces lifecycle operations do not imply that a group audio SFU is deployed.

## Deliberately not exposed as normal Flutter product routes

The client must not call OPTIONS preflight handlers, /internal/*, /readyz, /metrics, admin identity review endpoints, M-Pesa provider callbacks, replication ingress, CDN origin handlers, Algorithm, Federation or Data Centre private control-plane APIs. These are infrastructure, staff-only or server-to-server contracts.

When adding a feature, first verify the method and handler in the Backend router, add/update the corresponding BackendApi method and screen action, then add request-contract tests. Do not infer service origins from repository names or reuse the product API origin for another service without a verified ingress route.