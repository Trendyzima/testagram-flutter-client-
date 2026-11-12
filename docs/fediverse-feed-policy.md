# Fediverse feed presentation policy

`lib/features/federation/fediverse_feed_policy.dart` is a client-owned, deterministic presentation helper ported from the legacy Flutter source.

It reconciles a refreshed, Backend-authorized ActivityPub page with the reader's visible cards:
- keeps existing card order during refresh;
- stages newly discovered posts until explicit user action;
- de-duplicates by ActivityPub URI, object URL, or stable ID;
- removes a visible card when the refreshed page carries a tombstone;
- sorts staged additions by publication time.

The policy imports only Flutter foundation types. It contains no Supabase SDK, URL, key, session persistence, database/storage access, RPC, Edge Function, private service client, or server code.

**Authority boundary:** this helper is not an authorization or deletion authority. The canonical Testagram Backend must filter visibility, blocks, account eligibility and deletion before returning candidates. The Flutter client must not call Federation directly. A Backend response adapter and end-to-end feed integration remain separate work; this port does not claim federated-feed feature parity.
