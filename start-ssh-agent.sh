#!/bin/bash

# Usage: source ./start-ssh-agent.sh
# Set SSH_KEY_PATH to override ~/.ssh/id_ed25519.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    printf 'Usage: source %s (must run in the current Bash shell)\n' "$0" >&2
    exit 1
fi

cleanup_ssh_agent() {
    if [[ -n "${SSH_AGENT_PID:-}" ]]; then
        ssh-agent -k >/dev/null 2>&1 || true
        unset SSH_AGENT_PID SSH_AUTH_SOCK
    fi
}

start_ssh_agent() {
    local ssh_key_path="${SSH_KEY_PATH:-${HOME}/.ssh/id_ed25519}"

    local agent_env

    agent_env="$(ssh-agent -s)" || return
    eval "${agent_env}"
    trap cleanup_ssh_agent EXIT
    ssh-add "${ssh_key_path}"
}

start_ssh_agent
