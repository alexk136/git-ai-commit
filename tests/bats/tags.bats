#!/usr/bin/env bats
# tests/bats/tags.bats — unit tests for lib/tags.sh semver logic.

load 'helpers/common'

setup() {
    load_tags
}

@test "tags: get_latest_numeric_tag returns nothing for empty repo" {
    cd "$(mktemp -d)"
    git init -q -b main
    run get_latest_numeric_tag
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "tags: get_latest_numeric_tag ignores non-semver tags" {
    cd "$(mktemp -d)"
    git init -q -b main
    git config user.email t@t && git config user.name t
    echo a > a && git add a && git commit -qm c
    git tag release-foo
    git tag v1.2.3
    run get_latest_numeric_tag
    [ "$status" -eq 0 ]
    [ "$output" = "v1.2.3" ]
}

@test "tags: SEMVER_TAG_PATTERN overrides the default regex" {
    cd "$(mktemp -d)"
    git init -q -b main
    git config user.email t@t && git config user.name t
    echo a > a && git add a && git commit -qm c
    git tag 1.2.3         # matches the custom pattern below
    git tag v1.2.3        # ignored by the custom pattern
    SEMVER_TAG_PATTERN='^[0-9]+\.[0-9]+\.[0-9]+$' run get_latest_numeric_tag
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.3" ]
}

@test "tags: prepare_next_numeric_tag starts at 0.1.0 with no prior tag" {
    cd "$(mktemp -d)"
    git init -q -b main
    git config user.email t@t && git config user.name t
    echo a > a && git add a && git commit -qm c
    # Avoid network call to remote
    prepare_next_numeric_tag patch false
    [ "$new_tag" = "v0.1.1" ]
}

@test "tags: prepare_next_numeric_tag patch bumps correctly" {
    cd "$(mktemp -d)"
    git init -q -b main
    git config user.email t@t && git config user.name t
    echo a > a && git add a && git commit -qm c
    git tag v1.2.3
    prepare_next_numeric_tag patch false
    [ "$new_tag" = "v1.2.4" ]
}

@test "tags: prepare_next_numeric_tag minor resets patch" {
    cd "$(mktemp -d)"
    git init -q -b main
    git config user.email t@t && git config user.name t
    echo a > a && git add a && git commit -qm c
    git tag v1.2.3
    prepare_next_numeric_tag minor false
    [ "$new_tag" = "v1.3.0" ]
}

@test "tags: prepare_next_numeric_tag major resets minor and patch" {
    cd "$(mktemp -d)"
    git init -q -b main
    git config user.email t@t && git config user.name t
    echo a > a && git add a && git commit -qm c
    git tag v1.2.3
    prepare_next_numeric_tag major false
    [ "$new_tag" = "v2.0.0" ]
}

@test "tags: prepare_next_numeric_tag rejects invalid bump" {
    cd "$(mktemp -d)"
    git init -q -b main
    git config user.email t@t && git config user.name t
    echo a > a && git add a && git commit -qm c
    git tag v1.2.3
    run prepare_next_numeric_tag invalid false
    [ "$status" -ne 0 ]
}
