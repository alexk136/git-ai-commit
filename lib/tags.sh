#!/usr/bin/env bash
# shellcheck shell=bash
# lib/tags.sh — semver tag parsing and bumping.

if [[ -n "${__GAIC_TAGS_LOADED:-}" ]]; then
    return 0
fi
__GAIC_TAGS_LOADED=1

SEMVER_TAG_PATTERN='^v[0-9]+\.[0-9]+\.[0-9]+$'

get_latest_numeric_tag() {
    git tag --sort=-v:refname 2>/dev/null \
        | grep -E "$SEMVER_TAG_PATTERN" \
        | head -n 1
}

# prepare_next_numeric_tag <bump_type> [fetch_tags=true]
# Sets global `new_tag` to the next version. Returns non-zero on error.
prepare_next_numeric_tag() {
    local bump_type="${1:-patch}"
    local fetch="${2:-true}"
    local last_tag version major minor patch

    if [[ "$fetch" == "true" ]] && ! git fetch --tags >/dev/null 2>&1; then
        ui_warn "Failed to fetch tags from remote; using local cache."
    fi

    last_tag=$(get_latest_numeric_tag)
    if [[ -z "$last_tag" ]]; then
        major=0; minor=1; patch=0
    else
        version=${last_tag#v}
        IFS='.' read -r major minor patch <<<"$version"
    fi

    case "$bump_type" in
        major) major=$((major + 1)); minor=0; patch=0 ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        patch) patch=$((patch + 1)) ;;
        *)
            ui_error "Invalid bump type: $bump_type (use patch, minor, or major)"
            return 1
            ;;
    esac

    new_tag="v${major}.${minor}.${patch}"
    return 0
}
