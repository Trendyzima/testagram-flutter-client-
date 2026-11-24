#!/usr/bin/env bash
set -euo pipefail

accepted_response() {
  # A release probe is successful only when the canonical native signup route
  # reaches password validation. Identity-review gates are not valid readiness:
  # ordinary account creation must not require staff evidence review.
  case "${1:-}:${2:-}" in
    400:INVALID_PASSWORD)
      printf '%s\n' "Native signup reached password validation; no account or email was created."
      ;;
    *)
      return 1
      ;;
  esac
}

assert_accepts() {
  accepted_response "$@" >/dev/null
}

assert_rejects() {
  if accepted_response "$@" >/dev/null 2>&1; then
    return 1
  fi
}

if [[ "${1:-}" == "--test" ]]; then
  assert_accepts 400 INVALID_PASSWORD
  assert_rejects 503 IDENTITY_REVIEW_REQUIRED
  assert_rejects 503 IDENTITY_REVIEW_MFA_UNAVAILABLE
  assert_rejects 503 INTERNAL_ERROR
  assert_rejects 200 OK
  assert_rejects 400 IDENTITY_REVIEW_REQUIRED
  printf '%s\n' "Native signup readiness policy regression tests passed."
  exit 0
fi

if [[ "$#" -ne 2 ]]; then
  echo "Usage: $0 <http-status> <error-code>" >&2
  exit 2
fi

accepted_response "$1" "$2"
