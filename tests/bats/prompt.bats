#!/usr/bin/env bats
# tests/bats/prompt.bats — unit tests for lib/prompt.sh.

load 'helpers/common'

setup() {
    load_prompt
}

@test "prompt: build_prompt english includes file summary" {
    local diff="diff --git a/x.txt b/x.txt
+++ b/x.txt
@@ -1 +1 @@
-old
+new"
    run build_prompt "$diff" "english" 200
    [ "$status" -eq 0 ]
    [[ "$output" == *"English"* ]]
    [[ "$output" == *"x.txt"* ]]
    [[ "$output" == *"200 chars"* ]]
}

@test "prompt: build_prompt russian uses russian instructions" {
    local diff="diff --git a/x.txt b/x.txt
+new"
    run build_prompt "$diff" "russian" 200
    [ "$status" -eq 0 ]
    [[ "$output" == *"русском"* ]]
    [[ "$output" == *"200 символов"* ]]
}

@test "prompt: build_fallback_prompt english" {
    local diff="diff --git a/x.txt b/x.txt
+new content"
    run build_fallback_prompt "$diff" "english" 100
    [ "$status" -eq 0 ]
    [[ "$output" == *"under 100 chars"* ]]
}

@test "prompt: build_fallback_prompt russian" {
    local diff="+new content"
    run build_fallback_prompt "$diff" "russian" 100
    [ "$status" -eq 0 ]
    [[ "$output" == *"до 100 символов"* ]]
}

@test "prompt: cleanup_message strips 'Here is a...:' prefix" {
    run cleanup_message "Here is a commit message: feat: add tests"
    [ "$status" -eq 0 ]
    [ "$output" = "feat: add tests" ]
}

@test "prompt: cleanup_message strips 'Commit message:' prefix" {
    run cleanup_message "Commit message: fix: handle nil"
    [ "$status" -eq 0 ]
    [ "$output" = "fix: handle nil" ]
}

@test "prompt: cleanup_message strips russian prefix" {
    run cleanup_message "Сообщение коммита: фикс: починить"
    [ "$status" -eq 0 ]
    [ "$output" = "фикс: починить" ]
}

@test "prompt: cleanup_message trims quotes" {
    run cleanup_message '"feat: quoted"'
    [ "$status" -eq 0 ]
    [ "$output" = "feat: quoted" ]
}

@test "prompt: cleanup_message collapses whitespace" {
    run cleanup_message $'feat:   add\n\ntests'
    [ "$status" -eq 0 ]
    [ "$output" = "feat: add tests" ]
}
