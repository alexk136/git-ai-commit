#!/usr/bin/env bash
# shellcheck shell=bash
# lib/config.sh — configuration loading.
#
# Resolution order (highest → lowest priority):
#   1. CLI flags (tracked via CLI_<KEY> sentinels, set by bin/git-ai-commit)
#   2. Environment variables
#   3. Per-repo config: <repo-root>/.gitaicommit
#   4. Global config: $XDG_CONFIG_HOME/git-ai-commit/config
#
# This module exposes a single function: `config_load`. It populates
# GAIC_CONFIG_FILES and prints the final value of every known key, one
# per line, in the form "KEY=value". The caller assigns into shell vars.

if [[ -n "${__GAIC_CONFIG_LOADED:-}" ]]; then
    return 0
fi
__GAIC_CONFIG_LOADED=1

# Recognized keys (whitelist). Add new ones here when extending.
CONFIG_KEYS=(
    PROVIDER MODEL BASE_URL API_KEY
    BUMP LANG ALWAYS_TAG
    MAX_COMMIT_MESSAGE_LENGTH MAX_SIMPLE_MESSAGE_LENGTH
    CURL_TIMEOUT CURL_RETRIES
)

# load_dotenv — source KEY=VALUE pairs from a .env file.
#
# Candidates (first existing wins):
#   $GAIC_DOTENV           explicit path (colon-separated for multiple)
#   <repo-root>/.env       auto-detected via `git rev-parse --show-toplevel`
#   ./.env                 current working directory
#
# Standard dotenv semantics: pre-set env vars are NOT overridden, so
# shell-exported values always win over .env. Supports `export ` prefix,
# blank lines, `#` comments, and double- or single-quoted values.
load_dotenv() {
    local candidates=()
    if [[ -n "${GAIC_DOTENV:-}" ]]; then
        IFS=: read -r -a candidates <<<"$GAIC_DOTENV"
    else
        if [[ -n "${GAIC_REPO_ROOT:-}" && -f "$GAIC_REPO_ROOT/.env" ]]; then
            candidates+=("$GAIC_REPO_ROOT/.env")
        fi
        if [[ -f "./.env" ]]; then
            candidates+=("./.env")
        fi
    fi

    local file line key value loaded=0
    for file in "${candidates[@]}"; do
        [[ -f "$file" ]] || continue
        while IFS= read -r line || [[ -n "$line" ]]; do
            line="${line#"${line%%[![:space:]]*}"}"
            [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
            [[ "${line:0:7}" == "export " ]] && line="${line:7}"
            [[ "$line" != *=* ]] && continue
            key="${line%%=*}"
            value="${line#*=}"
            key="${key#"${key%%[![:space:]]*}"}"
            key="${key%"${key##*[![:space:]]}"}"
            [[ -z "$key" ]] && continue
            if [[ "${#value}" -ge 2 && "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
                value="${value:1:-1}"
            elif [[ "${#value}" -ge 2 && "${value:0:1}" == "'" && "${value: -1}" == "'" ]]; then
                value="${value:1:-1}"
            else
                value="${value%% #*}"
                value="${value%"${value##*[![:space:]]}"}"
            fi
            if [[ -z "${!key:-}" ]]; then
                printf -v "$key" '%s' "$value"
                (( loaded++ )) || true
            fi
        done < "$file"
        ui_debug "Loaded .env: $file"
    done
    ui_debug "load_dotenv: set $loaded variable(s)"
}

config_discover_files() {
    GAIC_CONFIG_FILES=()
    if [[ -n "${GAIC_REPO_ROOT:-}" ]]; then
        local f
        for f in .gitaicommit .git-ai-commit .git-ai-commit.conf; do
            if [[ -f "$GAIC_REPO_ROOT/$f" ]]; then
                GAIC_CONFIG_FILES+=("$GAIC_REPO_ROOT/$f")
            fi
        done
    fi
    local global_dir="${XDG_CONFIG_HOME:-$HOME/.config}/git-ai-commit"
    if [[ -f "$global_dir/config" ]]; then
        GAIC_CONFIG_FILES+=("$global_dir/config")
    fi
}

# Look up <key> in already-loaded config files (per-repo first).
# Returns 0 on hit (prints value), 1 on miss.
config_file_lookup() {
    local key="$1"
    local file line value
    for file in "${GAIC_CONFIG_FILES[@]:-}"; do
        [[ -f "$file" ]] || continue
        while IFS= read -r line || [[ -n "$line" ]]; do
            # strip leading/trailing whitespace
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"
            [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
            [[ "$line" == "$key="* ]] || continue
            value="${line#"$key"=}"
            # drop trailing comment
            value="${value%% #*}"
            value="${value%"${value##*[![:space:]]}"}"
            # strip surrounding quotes
            if [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
                value="${value:1:-1}"
            elif [[ "${value:0:1}" == "'" && "${value: -1}" == "'" ]]; then
                value="${value:1:-1}"
            fi
            printf '%s' "$value"
            return 0
        done < "$file"
    done
    return 1
}

config_validate() {
    local key="$1" value="$2"
    case "$key" in
        PROVIDER)
            case "$value" in
                ollama|openai|openrouter|anthropic|minimax) return 0 ;;
                *) ui_error "Invalid PROVIDER '$value' (allowed: ollama|openai|openrouter|anthropic|minimax)"; return 1 ;;
            esac
            ;;
        BUMP)
            case "$value" in
                patch|minor|major) return 0 ;;
                *) ui_error "Invalid BUMP '$value' (allowed: patch|minor|major)"; return 1 ;;
            esac
            ;;
        MAX_COMMIT_MESSAGE_LENGTH|MAX_SIMPLE_MESSAGE_LENGTH|CURL_TIMEOUT|CURL_RETRIES)
            if [[ ! "$value" =~ ^[0-9]+$ ]] || [[ "$value" -le 0 ]]; then
                ui_error "Invalid $key '$value' (must be a positive integer)"; return 1
            fi
            ;;
        ALWAYS_TAG)
            case "${value,,}" in
                1|true|yes|on)  return 0 ;;
                0|false|no|off|"") return 0 ;;
                *) ui_error "Invalid ALWAYS_TAG '$value' (allowed: 0|1|true|false)"; return 1 ;;
            esac
            ;;
    esac
    [[ -n "$value" ]] && return 0
    return 1
}
