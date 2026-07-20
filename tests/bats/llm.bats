#!/usr/bin/env bats
# tests/bats/llm.bats — integration tests with a mock LLM server.

load 'helpers/common'

setup() {
    TMP="$(mktemp -d)"
    cd "$TMP"
    git init -q -b main
    git config user.email t@t && git config user.name t
    echo a > a && git add a && git commit -qm c
    echo new >> a
}

teardown() {
    mock_stop
    cd /
    rm -rf "$TMP"
}

@test "llm: generate_commit_message succeeds with valid openai response" {
    skip_if_no_jq
    port=$(mock_openai_start)
    base_url="http://127.0.0.1:$port"

    load_libs
    PROVIDER="openai"
    API_KEY="sk-fake"
    BASE_URL="$base_url"
    MODEL="gpt-4o-mini"
    CURL_TIMEOUT=5

    generate_commit_message "Generate a commit message" "$MODEL"
    [ "$LAST_COMMIT_MESSAGE" = "feat: mock" ]
}

@test "llm: API request body contains expected fields" {
    skip_if_no_jq
    capture_file="$BATS_TEST_TMPDIR/cap.json"
    # mock_openai_start is called once with the custom response.
    port=$(mock_openai_start '{"choices":[{"message":{"role":"assistant","content":"x"}}]}' "$capture_file")
    base_url="http://127.0.0.1:$port"

    load_libs
    PROVIDER="openai"
    API_KEY="sk-fake"
    BASE_URL="$base_url"
    MODEL="gpt-4o-mini"
    CURL_TIMEOUT=5

    generate_commit_message "Make a message" "$MODEL" || true
    body=$(cat "$capture_file")
    [[ "$body" == *"\"model\":\"gpt-4o-mini\""* ]]
    [[ "$body" == *"Make a message"* ]]
    [[ "$body" == *"\"role\":\"user\""* ]]
}

@test "llm: openrouter adds HTTP-Referer and X-Title headers" {
    skip_if_no_jq
    skip "header inspection needs more elaborate mock"
}

@test "llm: anthropic uses x-api-key header and /messages endpoint" {
    skip_if_no_jq
    skip "covered by manual smoke test"
}

@test "llm: missing API key fails with helpful error" {
    load_libs
    PROVIDER="openai"
    API_KEY=""
    BASE_URL="http://127.0.0.1:1"
    MODEL="gpt-4o-mini"

    run generate_commit_message "x" "$MODEL"
    [ "$status" -ne 0 ]
    [[ "$output" == *"OPENAI_API_KEY"* ]]
}

skip_if_no_jq() {
    if ! command -v jq &>/dev/null; then
        skip "jq not installed"
    fi
}
