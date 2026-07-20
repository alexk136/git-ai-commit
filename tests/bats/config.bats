#!/usr/bin/env bats
# tests/bats/config.bats — unit tests for lib/config.sh and config files.

load 'helpers/common'

setup() {
    load_config
    TMP="$(mktemp -d)"
    cd "$TMP"
    git init -q -b main
    git config user.email t@t && git config user.name t
    echo a > a && git add a && git commit -qm c
    export GAIC_REPO_ROOT="$TMP"
}

teardown() {
    cd /
    rm -rf "$TMP"
}

@test "config: file_lookup returns value for known key" {
    cat > .gitaicommit <<EOF
PROVIDER=openai
MODEL=gpt-4o
EOF
    config_discover_files
    run config_file_lookup PROVIDER
    [ "$status" -eq 0 ]
    [ "$output" = "openai" ]
}

@test "config: file_lookup returns 1 for missing key" {
    cat > .gitaicommit <<EOF
PROVIDER=openai
EOF
    config_discover_files
    run config_file_lookup BOGUS
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

@test "config: file_lookup strips comments and quotes" {
    cat > .gitaicommit <<EOF
# This is a comment
PROVIDER="openai"   # inline comment
LANG='russian'
EOF
    config_discover_files
    run config_file_lookup PROVIDER
    [ "$output" = "openai" ]
    run config_file_lookup LANG
    [ "$output" = "russian" ]
}

@test "config: validate PROVIDER accepts all known providers" {
    for p in ollama openai openrouter anthropic minimax; do
        run config_validate PROVIDER "$p"
        [ "$status" -eq 0 ]
    done
}

@test "config: validate PROVIDER rejects unknown" {
    run config_validate PROVIDER foobar
    [ "$status" -ne 0 ]
}

@test "config: validate BUMP accepts patch|minor|major" {
    for b in patch minor major; do
        run config_validate BUMP "$b"
        [ "$status" -eq 0 ]
    done
}

@test "config: validate numeric keys reject non-numbers" {
    run config_validate CURL_TIMEOUT "abc"
    [ "$status" -ne 0 ]
    run config_validate CURL_TIMEOUT "0"
    [ "$status" -ne 0 ]
    run config_validate CURL_TIMEOUT "30"
    [ "$status" -eq 0 ]
}
