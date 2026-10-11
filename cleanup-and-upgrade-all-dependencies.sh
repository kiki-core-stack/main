#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/scripts/libs/common.sh"

# Constants/Variables
readonly -a CLEANUP_DIRECTORY_NAMES=(
    '.nitro'
    '.nuxt'
    '.output'
    'dist'
    'node_modules'
)

readonly -a CLEANUP_FILE_NAMES=(
    'bun.lock'
    'bun.lockb'
    'Cargo.lock'
    'pnpm-lock.yaml'
)

# Functions
cleanup_dependency_artifacts() {
    local name
    local -a directory_match_args=(-false)
    local -a file_match_args=(-false)

    for name in "${CLEANUP_DIRECTORY_NAMES[@]}"; do
        directory_match_args+=(-o -name "${name}")
    done

    for name in "${CLEANUP_FILE_NAMES[@]}"; do
        file_match_args+=(-o -name "${name}")
    done

    find . -name .git -prune -o \
        \( -type d \( "${directory_match_args[@]}" \) -prune -exec rm -rf -- {} + \) -o \
        \( -type f \( "${file_match_args[@]}" \) -exec rm -f -- {} + \)
}

# Run
main() {
    cd "${SCRIPT_DIR}"

    log_info 'Cleaning dependency artifacts...'
    cleanup_dependency_artifacts
    log_success 'Cleaned dependency artifacts'

    "${SCRIPT_DIR}/upgrade-all-dependencies.sh"
    "${SCRIPT_DIR}/modify-files-permissions.sh"
}

main "$@"
