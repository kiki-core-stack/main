#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/scripts/libs/common.sh"

# Run
main() {
    (($# > 0)) || {
        log_error 'Usage: compose.sh <profile> <compose arguments>'
        return 1
    }

    local profile="$1"
    local profile_path="${SCRIPT_DIR}/profiles/${profile}/.env"
    shift
    [[ -f "${profile_path}" ]] || {
        log_error "Profile not found: ${profile_path}"
        return 1
    }

    # Compose accepts empty secrets, so check the profile before running.
    node "${SCRIPT_DIR}/scripts/profile.mjs" check "${profile}" >&2
    exec docker compose --project-directory "${SCRIPT_DIR}" --env-file "${profile_path}" "$@"
}

main "$@"
