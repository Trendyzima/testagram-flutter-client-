# Live Appwrite authentication verification (staging only)

The manually dispatched workflow `.github/workflows/appwrite-live-auth.yml` exercises the real Appwrite Account API using a disposable staging project. It is intentionally separate from ordinary CI and must not point at the production project.

## Configure the protected GitHub staging environment

Create a GitHub Environment named `staging`. Add these non-secret environment variables:

- `APPWRITE_STAGING_ENDPOINT`: the staging Appwrite endpoint ending in `/v1`
- `APPWRITE_STAGING_PROJECT_ID`: the disposable staging project ID
- `APPWRITE_STAGING_SITE_URL`: the HTTPS origin registered as a Web platform in that Appwrite project

Add these environment secrets:

- `APPWRITE_STAGING_EMAIL`: a mailbox dedicated to disposable Testagram auth tests
- `APPWRITE_STAGING_PASSWORD`: password for the disposable test account
- `APPWRITE_STAGING_NAME`: test account display name
- `APPWRITE_VERIFICATION_USER_ID` and `APPWRITE_VERIFICATION_SECRET`: values copied from the Appwrite verification link
- `APPWRITE_RECOVERY_USER_ID` and `APPWRITE_RECOVERY_SECRET`: values copied from the password recovery link
- `APPWRITE_RECOVERY_NEW_PASSWORD`: a new disposable test password

Never put production Appwrite IDs, API keys, session cookies, passwords, or email-link secrets in source files, workflow inputs, artifacts, or chat messages.

## Run the three phases in order

1. Dispatch **Appwrite live staging authentication**, phase `register`. This creates a disposable account, opens an email/password session and requests a verification email. Record the emitted user ID. Copy the user ID and secret from the verification email link into the protected staging secrets.
2. Dispatch phase `verify`. The runner redeems the verification token, signs in, checks that Appwrite reports `emailVerification=true`, and requests a password recovery email. Copy that email's user ID and secret into the protected staging secrets.
3. Dispatch phase `recover`. The runner redeems the recovery token, changes the password, signs in with the new password and checks the account is still verified.

The verification and recovery URLs use the same callback query contract consumed by the Flutter auth screen: `mode=verification` and `mode=recovery`.

## Release evidence and limits

A successful run proves the Appwrite staging API accepted the registration, session, verification, recovery and post-recovery login operations. It does not prove production project settings, SMTP deliverability to all providers, production redirect allowlists, Backend profile linking, or the complete Android/web browser deep-link experience. Those remain separate staging checks.

The runner does not create or delete production accounts and does not use an Appwrite server API key. Use a dedicated disposable project and mailbox. If a phase fails, retain only the redacted run URL and error code; do not publish verification or recovery secrets.
