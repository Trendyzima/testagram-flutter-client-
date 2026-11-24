#!/usr/bin/env bash
set -euo pipefail

accepted_response() {
  # Public signup must remain fail-closed until identity evidence review and
  # two-person approval are complete. Accept only the explicit review gate.
  case "${1:-}:${2:-}" in
    503:IDENTITY_REVIEW_REQUIRED)
      printf '%s\n' "Public signup remains fail-closed pending identity evidence review and two-person approval; no account or email was created."
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
  assert_accepts 503 IDENTITY_REVIEW_REQUIRED
  assert_rejects 400 INVALID_PASSWORD
  assert_rejects 503 IDENTITY_REVIEW_MFA_UNAVAILABLE
  assert_rejects 503 REGISTRATION_DISABLED
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
