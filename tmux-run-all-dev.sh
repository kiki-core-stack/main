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

# Functions
run_dev_server() {
    local script_path="${REPOS_DIR}/$1/${SCRIPT_NAME}"
    [[ -f "${script_path}" ]] || {
        log_warn "Skipped $1: repos/$1 not found"
        return 0
    }

    "${script_path}"
}

# Run
main() {
    node "${SCRIPT_DIR}/scripts/profile.mjs" render
    "${SCRIPT_DIR}/dev-gateway.sh" up -d
    run_dev_server ws.io-server
    sleep 3
    run_dev_server ops-workers-ts
    run_dev_server management-backend
    # The frontend generates files from the backend on start.
    sleep 3
    run_dev_server admin-frontend
}

main "$@"
