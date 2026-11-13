# Post interaction policy

`PostInteractionPolicy` is a small, deterministic Flutter-side helper extracted from the legacy XClone mobile feed interaction flow.

It only normalizes candidate post identifiers, recognizes HTTPS remote-object URI shapes, validates composer text length, and bounds requested list sizes.

It does **not** authenticate users, authorize interactions, resolve remote objects, query storage, or call a service. The canonical Testagram Backend remains authoritative for identity, permissions, visibility, moderation, and persistence.

The extraction intentionally excludes the legacy page and its Supabase dependency. No Supabase SDK, endpoint, key, session persistence, direct database/storage call, RPC, Edge Function, private service client, or backend code is included.
