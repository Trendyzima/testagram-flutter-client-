# XClone source extraction rules

The source repository is `Trendyzima/XClone-9b4dz1-9b4dz1-8936-20260809tr`; its Flutter app lives under `mobile/`. This repository is the standalone client and must not become a copy of the source monorepo.

## Allowed to migrate

- Pure Dart presentation helpers, formatting, validation and deterministic policy code.
- Flutter widgets that accept typed data and callbacks without owning network or persistence.
- Assets that are owned by Testagram and do not contain credentials or generated build output.
- Tests for the pure code being migrated, updated to the destination package paths.

## Excluded

- Supabase SDKs, imports, URLs, keys, migrations, Edge Functions, RPC clients and session storage.
- Direct database, object-storage, queue, cache or private-service access.
- Backend, Algorithm, Data Centre or Federation implementation code; those remain in their owning repositories.
- Generated files, build directories, lockfiles copied from the source app, signing keys, local configuration and secrets.
- Any screen whose data flow still depends on Supabase, until it is rewritten against a verified public Testagram Backend API contract.

## Required migration pattern

1. Inspect the source file and all of its imports/call sites.
2. Separate pure presentation/policy logic from persistence and service access.
3. Port only the independent logic and its focused tests.
4. Rebuild data access through the destination's Appwrite-authenticated Backend API client.
5. Never invent an API route or report a feature as complete just because a route or placeholder screen exists.
6. Run `dart run tool/check_dependency_boundary.dart`, `flutter analyze` and `flutter test` before merging.

## Extracted reusable client components

The current migration batch includes:
- `lib/features/discovery/sports_hub_policy.dart`: sports payload normalization and safe article URLs.
- `lib/core/media/media_upload_policy.dart`: client-side file extension, size and MIME validation.
- `lib/core/widgets/testagram_background.dart`: decorative Flutter background widget.
- `lib/features/migration_batch_policy.dart`: interest, UTC daily-claim, price and duration display policies.
- `lib/features/wallet/wallet_read_model.dart`: read-only wallet and transaction parsing; no payment or wallet mutation code.
- `lib/features/ads/ad_review_policy.dart`: ad-review control presentation rules; server authorization remains authoritative.
- `lib/features/creator/podcast_analytics_policy.dart`: defensive creator analytics display parsing.
- `lib/features/tv/tv_playback_policy.dart`: playback-surface, sponsored-ad eligibility, lifecycle pause/resume and validated YouTube URL policies.

Each migrated policy has focused tests. These utilities do not imply that their complete product screens, API integrations or backend capabilities have been migrated.

The owned Testagram launcher/brand image from `mobile/assets/branding/testagram-icon.webp` is also copied to `assets/branding/testagram-icon.webp` for the standalone client. It is declared as a Flutter asset; platform launcher generation remains a separate release task.

## First extracted component

`lib/features/discovery/sports_hub_policy.dart` is a pure payload-normalization and safe-link policy extracted from the source Flutter app. Its tests are migrated with it. This is a reusable utility only: it does not add a Sports Hub screen, provider integration, route or claim of feature parity. The full Sports Hub feature remains blocked until a supported backend/provider contract and UI are implemented.
