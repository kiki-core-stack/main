#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/scripts/libs/common.sh"

# Constants/Variables
readonly REPOS_DIR="${SCRIPT_DIR}/repos"
readonly SCRIPT_NAME='tmux-run-dev.sh'

# Run
main() {
    "${SCRIPT_DIR}/dev-gateway.sh" up -d
    "${REPOS_DIR}/ops-workers-ts/${SCRIPT_NAME}"
    "${REPOS_DIR}/management-backend/${SCRIPT_NAME}"
    # The frontend generates files from the backend on start.
    sleep 3
    "${REPOS_DIR}/admin-frontend/${SCRIPT_NAME}"
}

main "$@"
