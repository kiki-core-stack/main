#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

# Output is plain text for agents and chat: one status line per repository, then error excerpts and the autofix
# change report. Full tool output stays in per-repository logs that are kept only when something failed.

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/libs/common.sh"

# Constants/Variables
readonly EXCERPT_MAX_LINES=40
readonly EXCERPT_TAIL_LINES=15
readonly MAX_CONCURRENCY=4
readonly REPOS_DIR="${SCRIPT_DIR}/../repos"

KEEP_LOGS=0
LOG_DIR=''

# Functions
add_target() {
    local name="$1" dir="$2" report_skip="$3"
    local toolchain

    [[ -d "${dir}" ]] || return 0

    if [[ -f "${dir}/pnpm-lock.yaml" ]]; then
        toolchain='pnpm'
    elif [[ -f "${dir}/bun.lock" || -f "${dir}/bun.lockb" ]]; then
        toolchain='bun'
    elif [[ -f "${dir}/Cargo.lock" ]]; then
        toolchain='cargo'
    else
        [[ "${report_skip}" == 1 ]] && printf 'skip %s: no recognized lockfile\n' "${name}"
        return 0
    fi

    names+=("${name}")
    dirs+=("$(cd -P -- "${dir}" && pwd)")
    toolchains+=("${toolchain}")
}

cleanup() {
    stop_checks

    if [[ -n "${LOG_DIR}" && "${KEEP_LOGS}" != 1 ]]; then
        rm -rf -- "${LOG_DIR}"
    fi
}

# Prints "<hash>\t<path>" for every file that differs from HEAD (modified or untracked) and copies it into
# the snapshot directory so a later run can diff against its pre-autofix content.
snapshot_dirty() {
    local top="$1" scope="$2" snap_dir="${3:-}"
    local entry path hash

    while IFS= read -r -d '' entry; do
        path="${entry:3}"
        hash='-'

        if [[ -f "${top}/${path}" ]]; then
            hash="$(git -C "${top}" hash-object -- "${path}")"

            if [[ -n "${snap_dir}" ]]; then
                mkdir -p -- "${snap_dir}/$(dirname -- "${path}")"
                cp -- "${top}/${path}" "${snap_dir}/${path}"
            fi
        fi

        printf '%s\t%s\n' "${hash}" "${path}"
    done < <(git -C "${top}" status --porcelain=v1 -z --no-renames -uall -- "${scope}")
}

report_autofix() {
    local top="$1" scope="$2" before_file="$3" snap_dir="$4" out_file="$5"
    local -A before=()
    local hash path stat added deleted

    while IFS=$'\t' read -r hash path; do
        before["${path}"]="${hash}"
    done <"${before_file}"

    : >"${out_file}"

    while IFS=$'\t' read -r hash path; do
        if [[ "${before["${path}"]:-}" == "${hash}" ]]; then
            continue
        fi

        stat=''

        if [[ -n "${before["${path}"]+x}" && -f "${snap_dir}/${path}" && -f "${top}/${path}" ]]; then
            # The file was already dirty: only count what the autofix changed on top of it.
            stat="$(git diff --no-index --numstat -- "${snap_dir}/${path}" "${top}/${path}" || true)"
        else
            stat="$(git -C "${top}" diff --numstat HEAD -- "${path}" 2>/dev/null || true)"

            if [[ -z "${stat}" && -f "${top}/${path}" ]]; then
                stat="$(git diff --no-index --numstat -- /dev/null "${top}/${path}" || true)"
            fi
        fi

        if [[ -z "${stat}" ]]; then
            printf '(changed) %s\n' "${path}" >>"${out_file}"
            continue
        fi

        IFS=$'\t' read -r added deleted _ <<<"${stat%%$'\n'*}"

        if [[ "${added}" == '-' ]]; then
            printf '(binary) %s\n' "${path}" >>"${out_file}"
        else
            printf '+%s -%s %s\n' "${added}" "${deleted}" "${path}" >>"${out_file}"
        fi
    done < <(snapshot_dirty "${top}" "${scope}")
}

check_repo() (
    # Keep commands in the worker's process group for cancellation.
    set +m

    local index="$1" name="$2" dir="$3" toolchain="$4"
    local log_file="${LOG_DIR}/${index}.log"
    local before_file="${LOG_DIR}/${index}.before"
    local snap_dir="${LOG_DIR}/${index}.snap"
    local top='' joined
    local -a failed=()

    # fd 3 keeps the original stdout for the status line; everything else goes to the log.
    exec 3>&1 >>"${log_file}" 2>&1 </dev/null
    export NO_COLOR=1 CARGO_TERM_COLOR=never

    cd -P -- "${dir}"
    top="$(git rev-parse --show-toplevel 2>/dev/null)" || top=''

    if [[ -n "${top}" ]]; then
        snapshot_dirty "${top}" "${dir}" "${snap_dir}" >"${before_file}"
    fi

    run_step() {
        local label="$1" offset
        shift

        offset="$(wc -c <"${log_file}")"
        printf '$ %s\n' "$*"

        if "$@"; then
            return 0
        fi

        if tail -c "+$((offset + 1))" "${log_file}" | grep -qE 'heap out of memory|Ineffective mark-compacts'; then
            label+='(OOM)'
        fi

        failed+=("${label}")
    }

    # Apply fixes before validation so checks use the corrected source.
    if [[ "${toolchain}" == 'cargo' ]]; then
        run_step format cargo format-fix
        run_step lint cargo lint
    else
        run_step lint "${toolchain}" run lint:fix
        run_step typecheck "${toolchain}" run typecheck
    fi

    if [[ -n "${top}" ]]; then
        report_autofix "${top}" "${dir}" "${before_file}" "${snap_dir}" "${LOG_DIR}/${index}.autofix"
    fi

    rm -rf -- "${before_file}" "${snap_dir}"

    if ((${#failed[@]} > 0)); then
        printf -v joined '%s, ' "${failed[@]}"
        printf '%s\n' "${joined%, }" >"${LOG_DIR}/${index}.failed"
        printf 'FAIL %s: %s\n' "${name}" "${joined%, }" >&3
    else
        printf 'ok   %s\n' "${name}" >&3
    fi

    : >"${LOG_DIR}/${index}.done"
    ((${#failed[@]} == 0))
)

print_excerpt() {
    local log_file="$1" excerpt

    excerpt="$(
        awk -v max="${EXCERPT_MAX_LINES}" '
            /^[^[:space:]]/ { last_path = $0 }
            /^[[:space:]]+[0-9]+:[0-9]+[[:space:]]+error[[:space:]]/ {
                if (last_path != shown_path) { out[count++] = last_path; shown_path = last_path }
                out[count++] = $0
                next
            }
            /error TS[0-9]+/ || /^[^[:space:]]+:[0-9]+:[0-9]+: (error|warning)/ || (/^error(\[[A-Z0-9]+\])?: / && !/could not compile/) {
                out[count++] = $0
            }
            END {
                for (i = 0; i < count && i < max; i++) print out[i]
                if (count > max) printf "... %d more lines omitted\n", count - max
            }
        ' "${log_file}"
    )"

    if [[ -z "${excerpt}" ]]; then
        excerpt="$(tail -n "${EXCERPT_TAIL_LINES}" "${log_file}")"
    fi

    printf '%s\n' "${excerpt}"
}

stop_checks() {
    local pid

    for pid in $(jobs -rp); do
        kill -TERM -- "-${pid}" 2>/dev/null || true
    done

    wait || true
}

# Run
main() {
    local dir name index total failed_count=0 has_autofix=0 line
    local -a names=() dirs=() toolchains=() failed_indexes=()

    LOG_DIR="$(mktemp -d)"

    # Give each worker its own process group so signals also stop its commands.
    set -m
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    trap 'exit 129' HUP

    add_target pack "${SCRIPT_DIR}/../../pack" 0
    add_target pack-rs "${SCRIPT_DIR}/../../pack-rs" 0
    add_target base-backend "${SCRIPT_DIR}/../../base-backend" 0

    for dir in "${REPOS_DIR}"/*; do
        add_target "${dir##*/}" "${dir}" 1
    done

    total=${#names[@]}

    for index in "${!names[@]}"; do
        while (($(jobs -rp | wc -l) >= MAX_CONCURRENCY)); do
            wait -n || true
        done

        check_repo "${index}" "${names[index]}" "${dirs[index]}" "${toolchains[index]}" &
    done

    wait || true

    for index in "${!names[@]}"; do
        if [[ ! -f "${LOG_DIR}/${index}.done" ]]; then
            # The worker died before reporting.
            printf 'FAIL %s: worker error\n' "${names[index]}"
            printf 'worker error\n' >"${LOG_DIR}/${index}.failed"
        fi

        if [[ -f "${LOG_DIR}/${index}.failed" ]]; then
            failed_indexes+=("${index}")
        fi
    done

    failed_count=${#failed_indexes[@]}

    for index in "${failed_indexes[@]}"; do
        printf '\n--- %s: %s ---\n' "${names[index]}" "$(<"${LOG_DIR}/${index}.failed")"
        print_excerpt "${LOG_DIR}/${index}.log"
    done

    for index in "${!names[@]}"; do
        if [[ -s "${LOG_DIR}/${index}.autofix" ]]; then
            if ((has_autofix == 0)); then
                printf '\nAutofix changes:\n'
                has_autofix=1
            fi

            printf '%s\n' "${names[index]}"

            while IFS= read -r line; do
                printf '  %s\n' "${line}"
            done <"${LOG_DIR}/${index}.autofix"
        fi
    done

    if ((has_autofix == 0)); then
        printf '\nAutofix changes: none\n'
    fi

    if ((failed_count > 0)); then
        KEEP_LOGS=1
        printf '\nLogs: %s\n' "${LOG_DIR}"
        printf '%d of %d repositories failed\n' "${failed_count}" "${total}"
    else
        printf '\nAll %d repositories passed\n' "${total}"
    fi

    trap - INT TERM HUP
    return "$((failed_count > 0))"
}

main "$@"
