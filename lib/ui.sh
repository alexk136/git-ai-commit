#!/usr/bin/env bash
# shellcheck shell=bash
# lib/ui.sh — colored output and logging helpers.
# Sourced; not executable on its own.

# Guard against double-sourcing.
if [[ -n "${__GAIC_UI_LOADED:-}" ]]; then
    return 0
fi
__GAIC_UI_LOADED=1

# Force-disable colors when stdout/stderr is not a TTY or NO_COLOR is set.
if [[ -n "${NO_COLOR:-}" ]] || { [[ -t 1 ]] && [[ -z "${FORCE_COLOR:-}" ]]; }; then
    : # leave decision to the block below
fi

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]] && [[ "${TERM:-dumb}" != "dumb" ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_MAGENTA=$'\033[35m'
    C_CYAN=$'\033[36m'
else
    C_RESET="" C_BOLD="" C_DIM="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_MAGENTA="" C_CYAN=""
fi

# Log levels: 0=debug, 1=info, 2=warn, 3=error
GAIC_LOG_LEVEL="${GAIC_LOG_LEVEL:-1}"

_log() {
    local level="$1"; shift
    local color="$1"; shift
    local prefix="$1"; shift
    if [[ "$level" -ge "$GAIC_LOG_LEVEL" ]]; then
        printf '%s%s%s %s\n' "$color" "$prefix" "$C_RESET" "$*" >&2
    fi
}

ui_debug() { _log 0 "$C_DIM" "·" "$@"; }
ui_info()  { _log 1 "$C_CYAN" "ℹ" "$@"; }
ui_ok()    { _log 1 "$C_GREEN" "✅" "$@"; }
ui_warn()  { _log 2 "$C_YELLOW" "⚠" "$@"; }
ui_error() { _log 3 "$C_RED" "❌" "$@"; }
ui_step()  { _log 1 "$C_BLUE" "▶" "$@"; }
ui_arrow() { _log 1 "$C_MAGENTA" ">>>" "$@"; }

# die <message> — print error and exit 1
die() {
    ui_error "$@"
    exit 1
}

# require_cmd <cmd> — fail fast if a required binary is missing
require_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
}
