# Public account registration and identity-review separation

## Permanent default policy

Ordinary Testagram account creation MUST NOT require identity evidence submission,
manual identity review, or two-person identity approval. A user creates an account
through the native signup API, verifies their email, and then signs in.

Identity verification is a separate, optional workflow. It may be required later
for a specifically documented high-risk capability, regulated operation, or
privileged role. It MUST NOT be used as a blanket prerequisite for ordinary
registration, email verification, or basic account access.

## Build-time lock

The public identity application UI is deliberately disabled in all builds:

- `AppConfig.enableIdentityRegistrationUi` is a source constant set to false.
- `AuthScreen` ignores caller-supplied identity enrollment flags.
- The retired `TESTAGRAM_IDENTITY_REGISTRATION_UI_ENABLED` dart-define and
  environment variable are rejected by the production build script.
- `tool/identity-registration-build-guard.sh` is run by CI and the Pages build.
- Production signup readiness must reach ordinary password validation with an
  intentionally invalid password; it must not expect an identity-review denial.

Do not remove or weaken this guard as part of routine dependency updates,
Flutter regeneration, platform scaffolding, release builds, or deployment work.

## Re-enabling identity enrollment

Re-enabling public identity enrollment is a security/product policy change, not
a build toggle. It requires an explicit reviewed source change, updated policy
documentation, tests demonstrating that ordinary signup remains independent,
and an explicit owner-approved pull request. No CI variable, build argument,
flavor, or deployment secret may silently turn it on.

This policy does not authorize automatic identity approval, administrator
provisioning, privilege escalation, or bypassing email verification and
server-side authorization.
