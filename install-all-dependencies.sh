#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/scripts/libs/common.sh"
source "${SCRIPT_DIR}/scripts/libs/dependencies.sh"

# Run
main() {
    run_dependency_scripts "${SCRIPT_DIR}" 'install-dependencies.sh'
}

main "$@"
