#!/usr/bin/env bash
set -euo pipefail

export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
export PUB_ENVIRONMENT=cloudflare_pages

if ! command -v flutter >/dev/null 2>&1; then
  echo "Installing the current stable Flutter SDK for Cloudflare Pages..."
  releases_json="$(mktemp)"
  archive_file="$(mktemp --suffix=.tar.xz)"
  trap 'rm -f "$releases_json" "$archive_file"' EXIT
  curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
    https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json \
    -o "$releases_json"
  read -r archive version < <(python3 - "$releases_json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
stable_hash = data["current_release"]["stable"]
release = next(item for item in data["releases"] if item["hash"] == stable_hash)
print(release["archive"], release["version"])
PY
)
  echo "Using Flutter $version"
  curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
    "https://storage.googleapis.com/flutter_infra_release/releases/$archive" \
    -o "$archive_file"
  mkdir -p /tmp/testagram-flutter-sdk
  tar -xJf "$archive_file" -C /tmp/testagram-flutter-sdk
  export PATH="/tmp/testagram-flutter-sdk/flutter/bin:$PATH"
fi

flutter config --no-analytics
flutter --version
flutter create --org com.testagram --project-name app --platforms=web .
flutter pub get
dart run tool/check_dependency_boundary.dart
flutter analyze
flutter test --reporter expanded

TESTAGRAM_API_URL="${TESTAGRAM_API_URL:-https://api.testagram.site}"
TESTAGRAM_IDENTITY_REGISTRATION_UI_ENABLED="${TESTAGRAM_IDENTITY_REGISTRATION_UI_ENABLED:-false}"
flutter build web --release --base-href / \
  --dart-define="TESTAGRAM_API_URL=$TESTAGRAM_API_URL" \
  --dart-define="TESTAGRAM_IDENTITY_REGISTRATION_UI_ENABLED=$TESTAGRAM_IDENTITY_REGISTRATION_UI_ENABLED"

install -D cloudflare-pages/_headers build/web/_headers
version="${CF_PAGES_COMMIT_SHA:-$(git rev-parse --short HEAD)}"
sed -i "s#flutter_bootstrap\\.js#flutter_bootstrap.js?v=$version#g" build/web/index.html
sed -i "s#main\\.dart\\.js#main.dart.js?v=$version#g" build/web/flutter_bootstrap.js

test -s build/web/index.html
test -s build/web/flutter_bootstrap.js
test -s build/web/main.dart.js
grep -Fq "flutter_bootstrap.js?v=$version" build/web/index.html
grep -Fq "main.dart.js?v=$version" build/web/flutter_bootstrap.js
# The Create account entry point is always present. Actual application
# submission remains separately gated by TESTAGRAM_IDENTITY_REGISTRATION_UI_ENABLED.
for marker in 'Sign in' 'Reset password'; do
  grep -aFq "$marker" build/web/main.dart.js || {
    echo "::error::Flutter production bundle is missing authentication UI marker: $marker"
    exit 1
  }
done
if [[ "$TESTAGRAM_IDENTITY_REGISTRATION_UI_ENABLED" == "true" ]]; then
  grep -aFq 'Submit application' build/web/main.dart.js || {
    echo "::error::Flutter production bundle is missing enabled registration UI marker."
    exit 1
  }
fi
echo "Flutter web output validated at build/web"
