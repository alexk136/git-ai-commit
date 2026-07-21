#!/usr/bin/env bash
# shellcheck shell=bash
# lib/git.sh — git plumbing helpers used by the main flow.

if [[ -n "${__GAIC_GIT_LOADED:-}" ]]; then
    return 0
fi
__GAIC_GIT_LOADED=1

# require_clean_working_tree — refuse to operate on staged or unstaged
# changes in push-only paths (e.g. Ollama-down fallback).
require_clean_working_tree() {
    if [[ -n "$(git diff --cached)" || -n "$(git diff)" ]]; then
        ui_error "Uncommitted changes detected. Commit or stash them first."
        return 1
    fi
    return 0
}

unpushed_commits() {
    local branch
    branch=$(git branch --show-current 2>/dev/null) || return 1
    git log "origin/${branch}..HEAD" --oneline 2>/dev/null
}

current_branch() {
    git branch --show-current 2>/dev/null
}
