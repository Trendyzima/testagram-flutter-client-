# Testagram deep-link routing contract

## Supported destinations

| Destination | Canonical URL | App action |
|---|---|---|
| Public username profile | `https://testagram.site/@{username}` or `/u/{username}` | Resolve username through the authenticated Backend, then open the canonical profile UUID |
| UUID profile | `https://testagram.site/profile/{user_id}` | Open the profile using the canonical UUID |
| Wallet | `https://testagram.site/wallet` | Open the wallet landing screen only |
| Hashtag timeline | `https://testagram.site/tags/{tag}` | Open the Backend privacy-filtered hashtag timeline |

The native Testagram scheme supports `testagram://profile/{username}`, `testagram://tag/{tag}` and `testagram://wallet` when a platform runner explicitly registers it.

## Security and authorization

- Only `https://testagram.site`, `https://www.testagram.site`, the registered `testagram:` scheme and local application route names are accepted.
- Non-HTTPS web URLs, unknown hosts, user-info URLs, fragments, query strings, malformed handles and unsupported paths are rejected.
- Username resolution uses `testagram.social.profile.resolve`; Backend discoverability, protected-account, accepted-follow and block checks remain authoritative.
- The incoming destination is carried through the authentication gate. A deep link never grants access to a private profile or bypasses session validation.
- Wallet links are navigation-only. They cannot specify recipient, amount, phone number, checkout ID or payment operation. No wallet movement can be initiated by opening a link.

## Wallet retry safety

- The normalized Kenyan Safaricom phone, KES amount and idempotency key are persisted in secure storage before the first request.
- A retry of an ambiguous request reuses the same key and exact payload.
- The Backend binds each key to its original payload and supports owner-scoped status recovery by that key.
- A new, different deposit is blocked while a previous request remains ambiguous.
- An STK Push is not settlement. The displayed balance remains the Backend ledger balance until provider-verified settlement commits.

## Platform association release gates

This repository currently has Dart client sources but no Android or iOS runner projects. Before native deep links can be accepted:
- Android must host a verified `/.well-known/assetlinks.json` matching the release package and signing certificate.
- iOS must host `/.well-known/apple-app-site-association` and ship the matching Associated Domains entitlement.
- Cold-start and warm-start link delivery must be tested on signed Android and iOS builds.
- Web routing, this Dart parser and a successful web build do not prove native App Links or Universal Links.

## Not yet in this implementation

Post, notification, thread and Federation activity links are not routed by this candidate. They must be added only after their Backend resource lookup, authorization and canonical route contracts are verified. In particular, no link should render content that the authenticated viewer could not otherwise read.
