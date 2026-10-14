#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/libs/common.sh"

# Constants/Variables
readonly MAX_CONCURRENCY=4
readonly REPOS_DIR="${SCRIPT_DIR}/../repos"

# Functions
check_repo() (
    # Keep commands in the worker's process group for cancellation.
    set +m

    local repo_dir="$1"
    local repo_name="${repo_dir##*/}"
    local toolchain status=0

    cd "${repo_dir}" || return

    if [[ -f pnpm-lock.yaml ]]; then
        toolchain='pnpm'
    elif [[ -f bun.lock || -f bun.lockb ]]; then
        toolchain='bun'
    elif [[ -f Cargo.lock ]]; then
        toolchain='cargo'
    else
        log_warn "Skipping repository without a recognized lockfile: ${repo_name}"
        return 0
    fi

    log_info "Checking ${repo_name} with ${toolchain}..."

    # Apply fixes before validation so checks use the corrected source.
    if [[ "${toolchain}" == 'cargo' ]]; then
        if ! cargo format-fix; then
            log_error "Formatting failed: ${repo_name}"
            status=1
        fi

        if ! cargo lint; then
            log_error "Lint failed: ${repo_name}"
            status=1
        fi
    else
        if ! "${toolchain}" run lint:fix; then
            log_error "Lint failed: ${repo_name}"
            status=1
        fi

        if ! "${toolchain}" run typecheck; then
            log_error "Typecheck failed: ${repo_name}"
            status=1
        fi
    fi

    if ((status == 0)); then
        log_success "Checks passed: ${repo_name}"
    fi

    return "${status}"
)

stop_checks() {
    local pid

    for pid in "${pids[@]}"; do
        kill -TERM -- "-${pid}" 2>/dev/null || true
    done

    wait || true
}

# Run
main() {
    local repo_dir status=0
    local -a pids=()

    # Give each worker its own process group so signals also stop its commands.
    set -m
    trap stop_checks EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    trap 'exit 129' HUP

    for repo_dir in "${REPOS_DIR}"/*; do
        [[ -d "${repo_dir}" ]] || continue

        check_repo "${repo_dir}" &
        pids+=("$!")

        if ((${#pids[@]} >= MAX_CONCURRENCY)); then
            if ! wait "${pids[0]}"; then
                status=1
            fi

            pids=("${pids[@]:1}")
        fi
    done

    while ((${#pids[@]} > 0)); do
        if ! wait "${pids[0]}"; then
            status=1
        fi

        pids=("${pids[@]:1}")
    done

    if ((status == 0)); then
        log_success 'All repository checks completed'
    else
        log_error 'Repository checks completed with failures'
    fi

    trap - EXIT INT TERM HUP
    return "${status}"
}

main "$@"
