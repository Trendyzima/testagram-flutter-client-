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

## First extracted component

`lib/features/discovery/sports_hub_policy.dart` is a pure payload-normalization and safe-link policy extracted from the source Flutter app. Its tests are migrated with it. This is a reusable utility only: it does not add a Sports Hub screen, provider integration, route or claim of feature parity. The full Sports Hub feature remains blocked until a supported backend/provider contract and UI are implemented.
