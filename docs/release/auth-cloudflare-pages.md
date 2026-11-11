# Testagram authentication on Cloudflare Pages

## Public entry points

The Flutter web client is deployed as the Cloudflare Pages project `testagram-flutter-web`.

The auth screen supports direct entry links:

- Sign in: `/?mode=signin`
- Sign up: `/?mode=signup`
- Request password reset: `/?mode=forgot`
- Appwrite email verification callback: `/?mode=verification&userId=...&secret=...`
- Appwrite password recovery callback: `/?mode=recovery&userId=...&secret=...`

The Appwrite verification and recovery URLs must use the exact HTTPS origin registered as a Web platform in the Appwrite project. The Pages workflow injects `TESTAGRAM_SITE_URL` at build time (default `https://testagram.site`); set the GitHub production variable to the approved canonical origin before a production build.

## Identity and authorization

- Appwrite owns email/password credentials, verification, sessions and password recovery.
- Flutter must not store Appwrite API keys or service credentials.
- The Backend validates every Appwrite session JWT with Appwrite's authenticated Account endpoint and resolves the canonical Testagram identity through the explicit identity bridge.
- A successful Appwrite signup does not by itself prove that a canonical Testagram profile has been provisioned or linked. The Backend must reject unlinked identities; never auto-link by matching email.
- Unverified Appwrite sessions must not unlock product APIs. Both the Flutter gate and Backend authorization enforce email verification.

## Cloudflare Pages response policy

`web/_headers` is copied into the Flutter web output. It applies no-referrer, nosniff, frame denial and HSTS. The root HTML is revalidated so auth callback state is not held in a stale document cache. The global no-referrer policy is important because Appwrite verification and recovery callback URLs contain one-time secrets in query parameters.

Do not add a permissive Content-Security-Policy without first auditing Flutter's generated bootstrap, runtime script and Appwrite network requirements. Do not place Appwrite server API keys, Backend secrets or Cloudflare tokens in `--dart-define`; all values compiled into Flutter web are public.

## Staging test sequence

Use a dedicated disposable Appwrite staging project and mailbox, not production credentials.

1. Register a disposable user through the deployed Pages preview.
2. Confirm the verification email arrives and its callback opens the preview origin.
3. Redeem the verification link and confirm Appwrite reports `emailVerification=true`.
4. Sign in and verify the Backend accepts the JWT only after email verification and an explicit canonical identity link exists.
5. Request a password reset for both a known and unknown address; the UI response must not reveal which address exists.
6. Redeem the one-time recovery link, set a new password, and sign in using the new password.
7. Confirm expired/reused links fail safely and no callback secret appears in referrer headers, application logs or build artifacts.

The workflow `.github/workflows/appwrite-live-auth.yml` is a separate manual staging API exercise. It does not prove the browser callback or production email deliverability. Production domain association, DNS and nameserver changes are separate, explicitly approved release operations.
