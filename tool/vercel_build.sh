#!/usr/bin/env bash
set -euo pipefail

FLUTTER_DIR="${FLUTTER_DIR:-/tmp/flutter-sdk}"
if ! command -v flutter >/dev/null 2>&1; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
  export PATH="$FLUTTER_DIR/bin:$PATH"
fi

flutter config --enable-web
flutter create --org com.xclone --project-name app --platforms=web .
flutter pub get
flutter build web --release \
  --dart-define="APPWRITE_ENDPOINT=${APPWRITE_ENDPOINT:-}" \
  --dart-define="APPWRITE_PROJECT_ID=${APPWRITE_PROJECT_ID:-}" \
  --dart-define="TESTAGRAM_API_URL=${TESTAGRAM_API_URL:-}"
