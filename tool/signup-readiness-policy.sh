#!/usr/bin/env bash
set -euo pipefail

accepted_response() {
  # The canonical API is ready when password validation is reachable, or when
  # ordinary signup is correctly blocked pending identity evidence and two-person approval.
  case "${1:-}:${2:-}" in
    400:INVALID_PASSWORD)
      printf '%s\n' "Password validation is reachable; no account or email was created."
      ;;
    503:IDENTITY_REVIEW_REQUIRED)
      printf '%s\n' "Ordinary public signup is correctly fail-closed with IDENTITY_REVIEW_REQUIRED until identity evidence and two-person approval are complete."
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
  assert_accepts 503 IDENTITY_REVIEW_REQUIRED
  assert_rejects 503 IDENTITY_REVIEW_MFA_UNAVAILABLE
  assert_rejects 503 INTERNAL_ERROR
  assert_rejects 200 OK
  assert_rejects 400 IDENTITY_REVIEW_REQUIRED
  printf '%s\n' "Signup readiness policy regression tests passed."
  exit 0
fi

if [[ "$#" -ne 2 ]]; then
  echo "Usage: $0 <http-status> <error-code>" >&2
  exit 2
fi

accepted_response "$1" "$2"
