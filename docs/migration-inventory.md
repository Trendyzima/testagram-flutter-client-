# XClone to Flutter migration inventory

The legacy XClone repository contains a Flutter migration foundation under `mobile/` (272 tracked paths at the inspected baseline). It is not yet a clean standalone client: its dependency graph and feature modules include legacy Supabase coupling, and its own migration README explicitly identifies substantial feature gaps.

This repository is the destination. Port feature behavior, not legacy data-access implementations. Every migrated feature must call a typed Testagram Backend client; it must not import a Supabase SDK or query Appwrite databases directly.

## Feature domains to port and verify

- Identity, account recovery, legal acceptance, profile onboarding and session lifecycle
- Home/following feeds, post details, replies, quote posts, reposts, bookmarks and scheduled posts
- Media selection, uploads, reservations, completion, download authorization and deletion
- Profiles, followers/following, lists, blocks, mutes and account privacy
- Search, discovery, hashtags, trends, topics, sports and news
- Notifications, in-app realtime/polling and device push
- Direct messages, team chat, inbox, encryption/key lifecycle, receipts and calls
- Stories, short videos, live video, audio spaces, TV/ IPTV and creator studio
- Communities, challenges, polls, events and federated identities/feeds
- Marketplace, storefronts, orders, wishlists, wallet, M-Pesa, credits and premium
- Creator analytics, referrals, rewards, advertising and campaign reporting
- Moderation, appeals, reports, verification, admin and regulator tools
- Accessibility, localization, offline cache, deep links, SEO/public web strategy and release signing

## Acceptance record

A feature is not complete because a route or screen exists. Record the following for every feature before marking it migrated:

1. Source XClone route(s) and current behavior inspected.
2. Backend endpoint and request/response schema verified against Backend implementation and OpenAPI.
3. Authorization, privacy, ownership and visibility enforced by Backend.
4. Loading, empty, offline, timeout, retry and error behavior implemented.
5. Device permissions and media lifecycle tested where applicable.
6. Unit/widget/integration tests pass.
7. Android and web behavior verified; iOS is separately built and tested where supported.
8. No Supabase, Upstash, direct database, private-service, or secret-bearing client dependency remains.

## Cutover rule

Do not delete, archive, rename, or redirect the XClone repository during feature development. Keep its production client and existing release identity available until the Flutter replacement passes the complete parity and data/session/deep-link/signing migration gates. Then perform a coordinated cutover across Backend, Algorithm, Data Centre and Federation contracts, and only then retire XClone.
