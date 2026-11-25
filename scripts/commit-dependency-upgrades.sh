#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/libs/common.sh"

# Constants/Variables
readonly COMMIT_MESSAGE='chore: upgrade deps'
readonly REPOS_DIR="${SCRIPT_DIR}/../repos"
readonly DEPENDENCY_FILE_PATTERN='(^|/)(Cargo\.lock|Cargo\.toml|bun\.lock|bun\.lockb|package\.json|pnpm-lock\.yaml)$'

# Functions
# A manifest change counts as an upgrade only when nothing but dependency version specs differs from HEAD:
# the same dependencies with the same options, and no other field changed.
is_version_only_change() {
    local repo_dir="$1"
    local manifest="$2"

    python3 - <(git -C "${repo_dir}" show "HEAD:${manifest}") "${repo_dir}/${manifest}" <<'PY'
import json
import sys
import tomllib

old_path, new_path = sys.argv[1:3]
with open(old_path, encoding='utf-8') as file:
    old_text = file.read()

with open(new_path, encoding='utf-8') as file:
    new_text = file.read()

def normalize_package_json(text):
    manifest = json.loads(text)
    for section in ('dependencies', 'devDependencies', 'optionalDependencies', 'peerDependencies', 'overrides'):
        if isinstance(manifest.get(section), dict):
            manifest[section] = {name: None for name in manifest[section]}

    if isinstance(manifest.get('pnpm'), dict) and isinstance(manifest['pnpm'].get('overrides'), dict):
        manifest['pnpm']['overrides'] = {name: None for name in manifest['pnpm']['overrides']}

    if 'packageManager' in manifest:
        manifest['packageManager'] = str(manifest['packageManager']).split('@')[0]

    return manifest

def normalize_cargo_dependencies(table):
    for section in ('dependencies', 'dev-dependencies', 'build-dependencies'):
        dependencies = table.get(section)
        if not isinstance(dependencies, dict):
            continue

        for name, spec in dependencies.items():
            if isinstance(spec, dict):
                dependencies[name] = {key: value for key, value in spec.items() if key not in ('branch', 'rev', 'tag', 'version')}
            else:
                dependencies[name] = None

def normalize_cargo_toml(text):
    manifest = tomllib.loads(text)
    normalize_cargo_dependencies(manifest)
    normalize_cargo_dependencies(manifest.get('workspace', {}))
    for target in manifest.get('target', {}).values():
        normalize_cargo_dependencies(target)

    return manifest

normalize = normalize_cargo_toml if new_path.endswith('Cargo.toml') else normalize_package_json
sys.exit(0 if normalize(old_text) == normalize(new_text) else 1)
PY
}

commit_repo() {
    local repo_dir="$1"
    local repo_name="${repo_dir##*/}"
    local file
    local -a files=()

    if ! git -C "${repo_dir}" diff --cached --quiet; then
        log_warn "Skipping repository with staged changes: ${repo_name}"
        return 0
    fi

    log_info "Pulling ${repo_name}..."
    if ! git -C "${repo_dir}" pull --ff-only --quiet; then
        log_warn "Skipping repository that cannot be fast-forwarded: ${repo_name}"
        return 0
    fi

    mapfile -t files < <(git -C "${repo_dir}" diff --name-only | grep -E "${DEPENDENCY_FILE_PATTERN}" || true)
    if ((${#files[@]} == 0)); then
        log_info "No dependency changes: ${repo_name}"
        return 0
    fi

    for file in "${files[@]}"; do
        [[ "${file}" =~ (^|/)(Cargo\.toml|package\.json)$ ]] || continue
        if ! is_version_only_change "${repo_dir}" "${file}"; then
            log_warn "Skipping repository whose manifest changes more than versions: ${repo_name}: ${file}"
            return 0
        fi
    done

    git -C "${repo_dir}" add -- "${files[@]}"
    git -C "${repo_dir}" commit --quiet -m "${COMMIT_MESSAGE}"
    log_success "Committed dependency upgrades: ${repo_name}"
}

# Run
main() {
    local repo_dir

    for repo_dir in "${REPOS_DIR}"/*/; do
        repo_dir="${repo_dir%/}"
        [[ -d "${repo_dir}/.git" ]] || continue
        commit_repo "${repo_dir}"
    done
}

main "$@"
