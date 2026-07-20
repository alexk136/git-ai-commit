#!/usr/bin/env bats
# tests/bats/ui.bats — unit tests for lib/ui.sh.

load 'helpers/common'

@test "ui: ui_info prints to stderr" {
    run bash -c "
        source '$ROOT_DIR/lib/ui.sh'
        ui_info 'hello'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"hello"* ]]
}

@test "ui: die exits with status 1" {
    run bash -c "
        source '$ROOT_DIR/lib/ui.sh'
        die 'fatal'
    "
    [ "$status" -eq 1 ]
    [[ "$output" == *"fatal"* ]]
}

@test "ui: require_cmd fails for missing command" {
    run bash -c "
        source '$ROOT_DIR/lib/ui.sh'
        require_cmd this-command-does-not-exist-xyz
    "
    [ "$status" -eq 1 ]
    [[ "$output" == *"this-command-does-not-exist-xyz"* ]]
}

@test "ui: require_cmd passes for existing command" {
    run bash -c "
        source '$ROOT_DIR/lib/ui.sh'
        require_cmd bash
    "
    [ "$status" -eq 0 ]
}

@test "ui: log levels are respected" {
    run bash -c "
        source '$ROOT_DIR/lib/ui.sh'
        GAIC_LOG_LEVEL=3
        ui_info 'should-be-hidden'
        ui_error 'should-be-shown'
    "
    [ "$status" -eq 0 ]
    [[ "$output" != *"should-be-hidden"* ]]
    [[ "$output" == *"should-be-shown"* ]]
}
