#!/usr/bin/env bash

# shellcheck shell=bash

if [[ -n "${SCRIPT_LIBS_DEPENDENCIES_LOADED:-}" ]]; then
    return 0
fi

SCRIPT_LIBS_DEPENDENCIES_LOADED=1

# Functions
run_dependency_scripts() (
    local root="$1"
    local script_name="$2"
    local script_path directory

    cd "${root}" || return

    find . \( -name .git -o -name node_modules \) -prune -o \
        \( -type f -name "${script_name}" -print0 \) |
        while IFS= read -r -d '' script_path; do
            directory="${script_path%/*}"

            (
                cd "${directory}" || exit
                log_info "Running dependency script: ${PWD}/${script_name}..."

                if [[ -x "./${script_name}" ]]; then
                    "./${script_name}" || exit
                else
                    bash "./${script_name}" || exit
                fi

                log_success "Finished dependency script: ${PWD}/${script_name}"
            ) || return
        done
)
