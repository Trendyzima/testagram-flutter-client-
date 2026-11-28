#!/usr/bin/env bash
set -euo pipefail

config="lib/core/app_config.dart"
screen="lib/features/auth/auth_screen.dart"

if ! grep -Fq 'static const enableIdentityRegistrationUi = false;' "$config"; then
  echo "::error::Public identity-review enrollment must remain hard-disabled in AppConfig."
  exit 1
fi
if grep -Eq "enableIdentityRegistrationUi[[:space:]]*=[[:space:]]*bool\.fromEnvironment|TESTAGRAM_IDENTITY_REGISTRATION_UI_ENABLED" "$config"; then
  echo "::error::A build-time override can re-enable public identity enrollment."
  exit 1
fi
if ! grep -Fq '}) : enableIdentityRegistration = false;' "$screen"; then
  echo "::error::AuthScreen must ignore caller-supplied identity-enrollment flags."
  exit 1
fi
if grep -Eq 'TESTAGRAM_IDENTITY_REGISTRATION_UI_ENABLED=true|TESTAGRAM_IDENTITY_REGISTRATION_UI_ENABLED.*true' .github/workflows cloudflare-pages; then
  echo "::error::A CI or deployment configuration attempts to re-enable public identity enrollment."
  exit 1
fi

echo "Public identity enrollment is locked off in source, widgets, CI and production build configuration."
