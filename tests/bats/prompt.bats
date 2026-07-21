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
    run build_prompt "$diff" "english" 500
    [ "$status" -eq 0 ]
    [[ "$output" == *"English"* ]]
    [[ "$output" == *"x.txt"* ]]
    [[ "$output" == *"500 chars"* ]]
    # Full diff must be passed to the LLM, not just headers.
    [[ "$output" == *"-old"* ]]
    [[ "$output" == *"+new"* ]]
}

@test "prompt: build_prompt russian uses russian instructions" {
    local diff="diff --git a/x.txt b/x.txt
+new"
    run build_prompt "$diff" "russian" 500
    [ "$status" -eq 0 ]
    [[ "$output" == *"русском"* ]]
    [[ "$output" == *"500 символов"* ]]
    [[ "$output" == *"diff --git"* ]]
}

@test "prompt: build_prompt sends the full diff, not just file headers" {
    local diff="diff --git a/x.txt b/x.txt
index 1111..2222 100644
--- a/x.txt
+++ b/x.txt
@@ -1,3 +1,4 @@
 line one
+inserted in the middle
 line two
 line three"
    run build_prompt "$diff" "english" 500
    [ "$status" -eq 0 ]
    [[ "$output" == *"@@ -1,3 +1,4 @@"* ]]
    [[ "$output" == *"inserted in the middle"* ]]
}

@test "prompt: PROMPT_TEMPLATE_EN overrides the english template" {
    local diff="diff --git a/x.txt b/x.txt
+new"
    PROMPT_TEMPLATE_EN='Custom %s chars EN: %s.' run build_prompt "$diff" "english" 42
    [ "$status" -eq 0 ]
    # Full diff is passed verbatim (newline between header and hunk preserved).
    [ "$output" = $'Custom 42 chars EN: diff --git a/x.txt b/x.txt\n+new.' ]
}

@test "prompt: build_fallback_prompt english" {
    local diff="diff --git a/x.txt b/x.txt
+new content"
    run build_fallback_prompt "$diff" "english" 1000
    [ "$status" -eq 0 ]
    [[ "$output" == *"under 1000 chars"* ]]
    [[ "$output" == *"diff --git"* ]]
}

@test "prompt: build_fallback_prompt russian" {
    local diff="+new content"
    run build_fallback_prompt "$diff" "russian" 1000
    [ "$status" -eq 0 ]
    [[ "$output" == *"до 1000 символов"* ]]
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
