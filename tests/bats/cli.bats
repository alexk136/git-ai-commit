#!/usr/bin/env bats
# tests/bats/cli.bats — end-to-end tests invoking bin/git-ai-commit.

load 'helpers/common'

setup() {
    TMP="$(mktemp -d)"
    cd "$TMP"
    git init -q -b main
    git config user.email t@t && git config user.name t
    echo a > a && git add a && git commit -qm c
    echo new >> a
    BIN="$ROOT_DIR/bin/git-ai-commit"
}

teardown() {
    mock_stop
    cd /
    rm -rf "$TMP"
}

@test "cli: --help exits 0" {
    run "$BIN" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"git-ai-commit"* ]]
    [[ "$output" == *"--provider"* ]]
    [[ "$output" == *"openrouter"* ]]
}

@test "cli: works when invoked through a symlink (portable resolver)" {
    link="$TMP/git-commit-link"
    ln -s "$BIN" "$link"
    run "$link" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"git-ai-commit"* ]]
}

@test "cli: --install --install-dir DIR places the symlink" {
    dest="$TMP/bin"
    mkdir -p "$dest"
    run "$BIN" --install --install-dir "$dest"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Installed"* ]]
    [ -L "$dest/git-commit" ]
    [ "$(readlink "$dest/git-commit")" = "$BIN" ]
}

@test "cli: --install falls back to ~/.local/bin when no system dir is writable" {
    fakehome="$TMP/fakehome"
    mkdir -p "$fakehome"
    # Strip PATH so ~/.local/bin isn't pre-existing on it.
    run env -i HOME="$fakehome" PATH="/usr/bin:/bin" "$BIN" --install
    [ "$status" -eq 0 ]
    [ -L "$fakehome/.local/bin/git-commit" ]
    [[ "$output" == *"~/.local/bin"* || "$output" == *".local/bin"* ]]
}

@test "cli: --tag patch --dry-run prints next version" {
    run "$BIN" --tag patch --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"v0.1.1"* ]]
}

@test "cli: --tag minor --dry-run bumps minor" {
    run "$BIN" --tag minor --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"v0.2.0"* ]]
}

@test "cli: --tag major --dry-run bumps major" {
    run "$BIN" --tag major --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"v1.0.0"* ]]
}

@test "cli: --tag rejects invalid bump" {
    run "$BIN" --tag bogus
    [ "$status" -ne 0 ]
}

@test "cli: ALWAYS_TAG=0 by default — --tag --dry-run without ALWAYS_TAG shows tag preview" {
    run env -u ALWAYS_TAG "$BIN" --tag patch --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"v0.1.1"* ]]
}

@test "cli: ALWAYS_TAG=1 invalid value is rejected" {
    run env ALWAYS_TAG=maybe "$BIN" --tag patch --dry-run
    [ "$status" -ne 0 ]
    [[ "$output" == *"ALWAYS_TAG"* ]]
}

@test "cli: ALWAYS_TAG=true is accepted as truthy" {
    run env ALWAYS_TAG=true "$BIN" --tag patch --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"v0.1.1"* ]]
}

@test "cli: per-repo .gitaicommit ALWAYS_TAG=1 is loaded" {
    cat > .gitaicommit <<EOF
ALWAYS_TAG=1
EOF
    run env -u ALWAYS_TAG "$BIN" --tag patch --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"v0.1.1"* ]]
}

@test "cli: unknown option is rejected" {
    run "$BIN" --no-such-flag
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown argument"* ]]
}

@test "cli: per-repo .gitaicommit is loaded" {
    if ! command -v jq &>/dev/null; then skip "jq not installed"; fi
    port=$(mock_openai_start)
    cat > .gitaicommit <<EOF
PROVIDER=openai
MODEL=gpt-4o-mini
API_KEY=sk-fake
BASE_URL=http://127.0.0.1:$port
EOF
    run "$BIN" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"openai model gpt-4o-mini"* ]]
    [[ "$output" == *"Generated message"* ]]
}

@test "cli: env var OPENAI_API_KEY auto-selects openai" {
    if ! command -v jq &>/dev/null; then skip "jq not installed"; fi
    port=$(mock_openai_start)
    run env OPENAI_API_KEY=sk-fake "$BIN" --base-url "http://127.0.0.1:$port" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Auto-selected provider: openai"* ]]
    [[ "$output" == *"openai model gpt-4o-mini"* ]]
}

@test "cli: missing API key for non-ollama provider fails" {
    env -u OPENAI_API_KEY -u OPENROUTER_API_KEY -u ANTHROPIC_API_KEY -u MINIMAX_API_KEY \
        run "$BIN" --provider openai
    [ "$status" -ne 0 ]
    [[ "$output" == *"OPENAI_API_KEY"* ]]
}
