#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/libs/common.sh"

# Constants/Variables
REPOS_DIR="$(cd -P -- "${SCRIPT_DIR}/.." && pwd)/repos"
readonly REPOS_DIR

# Functions
stop_updates() {
    local pid

    for pid in "${pids[@]}"; do
        kill -TERM -- "-${pid}" 2>/dev/null || true
    done

    wait || true
}

# Run
main() (
    local repo_dir pid status=0
    local -a pids=()

    set -m
    trap stop_updates EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    trap 'exit 129' HUP

    for repo_dir in "${REPOS_DIR}"/*; do
        [[ -d "${repo_dir}" ]] || continue

        (
            set +m
            log_info "Updating repository: ${repo_dir##*/}..."
            git -C "${repo_dir}" fetch --prune
            git -C "${repo_dir}" pull
            log_success "Updated repository: ${repo_dir##*/}"
        ) &

        pids+=("$!")
    done

    while ((${#pids[@]} > 0)); do
        pid="${pids[0]}"
        if ! wait "${pid}"; then
            status=1
        fi

        pids=("${pids[@]:1}")
    done

    return "${status}"
)

main "$@"
