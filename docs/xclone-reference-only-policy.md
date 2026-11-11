# XClone reference-only policy

**Status:** Active architectural boundary  
**Applies to:** `testagram-flutter-client-` and all seven Testagram repositories

## Decision

The XClone repository is archived. It is retained strictly as a read-only reference for standardising and verifying the native Flutter client's feature parity, interaction behaviour, navigation expectations and migration completeness.

XClone is not a production application dependency, service dependency, source of runtime data, release artifact, or deployment target.

## Permitted use

The Flutter team may inspect archived XClone source and documentation to:

- build a route-by-route feature parity inventory;
- understand legacy user journeys and expected interaction states;
- compare visual and accessibility behaviour;
- identify reusable Flutter patterns that can be reimplemented cleanly;
- verify migration coverage and identify intentionally retired features.

Reference material must be reimplemented in the canonical `testagram-flutter-client-` repository. Do not make the new client depend on archived source packages, Git submodules, generated binaries, or build outputs from XClone.

## Prohibited use

- Do not unarchive, reopen, or resume feature development in XClone as part of this migration.
- Do not import XClone packages, source files, generated code, assets by build-time path, or Git submodules into the new Flutter client.
- Do not call XClone APIs, services, hosted endpoints, databases, or deployment environments at runtime.
- Do not require XClone to build, test, sign, release, deploy, or operate any Testagram production component.
- Do not treat a feature as migrated merely because it works in the archived app.
- Do not route users to XClone as a fallback for incomplete native features.

## Canonical ownership

The new Flutter client owns native presentation, navigation, local state, device integration and public Backend API transport. Backend remains the authority for identity validation, authorization and product data. Data Centre owns storage/infrastructure operations. CDN owns media delivery. Federation and Algorithm remain private service integrations behind Backend.

The Flutter client must never connect directly to PostgreSQL, Appwrite databases, B2/R2 credentials, private service APIs, queues, Federation or Algorithm.

## Migration acceptance

A feature is complete only when all of the following are evidenced in the new Flutter repository:

1. A native implementation exists, or product owners have explicitly approved its retirement.
2. It uses a documented and tested public Backend contract.
3. Loading, empty, error, retry, permission-denied and offline states are handled where applicable.
4. Widget/unit tests cover core behaviour and regression cases.
5. Navigation, deep links, accessibility and platform behaviour are verified where applicable.
6. Android and web builds pass; device-specific functionality receives real-device smoke testing.
7. No runtime or build-time dependency on XClone exists.

The migration ledger should record the legacy route/reference, destination route, Backend contract, implementation path, tests and acceptance evidence. A parity percentage must be calculated from this ledger, not from repository activity or the continued availability of XClone.

## Release boundary

XClone retirement is separate from infrastructure hardening and production migration. Infrastructure changes must be independently tested and deployed through their own controlled release gates. The native Flutter release and any XClone user/data/session cutover require a separate approval after Flutter parity, signing continuity, deep-link migration, account/session handling and rollback plans are demonstrated.

Until that approval, keep the XClone archive intact as a historical/reference artifact. It must not be made a live production dependency.
