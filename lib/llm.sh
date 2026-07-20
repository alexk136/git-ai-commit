#!/usr/bin/env bash
# shellcheck shell=bash
# lib/llm.sh — LLM provider abstraction.
#
# Public entry point: generate_commit_message "<prompt>" "<model>"
# Populates global LAST_COMMIT_MESSAGE. Returns 0 on success (message may
# still be empty if the model returned no text), 1 on transport error.

if [[ -n "${__GAIC_LLM_LOADED:-}" ]]; then
    return 0
fi
__GAIC_LLM_LOADED=1

# Per-provider defaults -------------------------------------------------------

get_provider_default_model() {
    case "$1" in
        ollama)     echo "mistral-nemo:latest" ;;
        openai)     echo "gpt-4o-mini" ;;
        openrouter) echo "anthropic/claude-3.5-haiku" ;;
        anthropic)  echo "claude-3-5-haiku-latest" ;;
        minimax)    echo "MiniMax-M3" ;;
        *)          return 1 ;;
    esac
}

get_provider_default_base_url() {
    case "$1" in
        ollama)     echo "http://127.0.0.1:11434" ;;
        openai)     echo "https://api.openai.com/v1" ;;
        openrouter) echo "https://openrouter.ai/api/v1" ;;
        anthropic)  echo "https://api.anthropic.com/v1" ;;
        minimax)    echo "https://api.minimax.io/v1" ;;
        *)          return 1 ;;
    esac
}

get_provider_env_key() {
    case "$1" in
        openai)     echo "OPENAI_API_KEY" ;;
        openrouter) echo "OPENROUTER_API_KEY" ;;
        anthropic)  echo "ANTHROPIC_API_KEY" ;;
        minimax)    echo "MINIMAX_API_KEY" ;;
        *)          return 1 ;;
    esac
}

# Per-provider MODEL env var (e.g. OPENAI_MODEL=gpt-4o).
# Falls back to a generic GAIC_MODEL.
get_provider_env_model() {
    case "$1" in
        openai)     echo "OPENAI_MODEL" ;;
        openrouter) echo "OPENROUTER_MODEL" ;;
        anthropic)  echo "ANTHROPIC_MODEL" ;;
        minimax)    echo "MINIMAX_MODEL" ;;
        ollama)     echo "OLLAMA_MODEL" ;;
        *)          return 1 ;;
    esac
}

# API key resolution: --api-key beats env var beats nothing.
resolve_api_key() {
    local provider="$1"
    if [[ -n "${API_KEY:-}" ]]; then
        printf '%s' "$API_KEY"
        return 0
    fi
    local env_var
    env_var=$(get_provider_env_key "$provider") || return 0
    if [[ -n "${!env_var:-}" ]]; then
        printf '%s' "${!env_var}"
    fi
}

# Curl wrapper with timeout, retry, and HTTP status extraction.
# Sets globals LAST_HTTP_STATUS and LAST_RESPONSE_BODY.
_http_call() {
    local url="$1"; shift
    local attempt max_attempts delay
    max_attempts="${CURL_RETRIES:-2}"
    delay=1

    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
        local response
        response=$(curl --silent --show-error \
            --connect-timeout "${CURL_CONN_TIMEOUT:-5}" \
            --max-time "${CURL_TIMEOUT:-60}" \
            --retry 0 \
            -w "HTTP_STATUS:%{http_code}" \
            "$@" "$url" 2>/dev/null) || true

        LAST_HTTP_STATUS=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
        LAST_RESPONSE_BODY=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')

        # Retry on transport errors or 5xx
        if [[ -z "$LAST_HTTP_STATUS" ]] \
            || [[ "$LAST_HTTP_STATUS" -ge 500 && "$LAST_HTTP_STATUS" -lt 600 ]]; then
            if [[ "$attempt" -lt "$max_attempts" ]]; then
                ui_debug "Retry $((attempt + 1))/$max_attempts after ${delay}s..."
                sleep "$delay"
                delay=$((delay * 2))
                continue
            fi
        fi
        return 0
    done
}

# --- Provider-specific request functions ------------------------------------

_ollama_request() {
    local prompt="$1" model="$2"
    local clean_prompt
    clean_prompt=$(printf '%s' "$prompt" | tr '\n' ' ' | sed 's/"/\\"/g')
    _http_call "$BASE_URL/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"$model\", \"prompt\": \"$clean_prompt\", \"stream\": false}"
    if [[ "${LAST_HTTP_STATUS:-000}" != "200" ]]; then
        ui_error "Ollama API error (HTTP ${LAST_HTTP_STATUS:-?}): $LAST_RESPONSE_BODY"
        return 1
    fi
    if command -v jq &>/dev/null; then
        LAST_COMMIT_MESSAGE=$(printf '%s' "$LAST_RESPONSE_BODY" | jq -r '.response // empty')
    else
        LAST_COMMIT_MESSAGE=$(printf '%s' "$LAST_RESPONSE_BODY" \
            | grep -o '"response":"[^}]*"' \
            | sed 's/"response":"//' | sed 's/"$//' \
            | sed 's/\\n/ /g' | sed 's/\\"/"/g')
    fi
    return 0
}

_openai_compatible_request() {
    local prompt="$1" model="$2" provider="$3"
    local api_key
    api_key=$(resolve_api_key "$provider")
    if [[ -z "$api_key" ]]; then
        local env_var
        env_var=$(get_provider_env_key "$provider")
        ui_error "API key for $provider not found. Set $env_var or pass --api-key."
        return 1
    fi
    require_cmd jq

    local payload
    payload=$(jq -n --arg model "$model" --arg prompt "$prompt" '{
        model: $model,
        messages: [{role: "user", content: $prompt}],
        max_tokens: 2000,
        temperature: 0.3
    }')

    local headers=(
        -H "Content-Type: application/json"
        -H "Authorization: Bearer $api_key"
    )
    if [[ "$provider" == "openrouter" ]]; then
        headers+=(
            -H "HTTP-Referer: https://github.com/local/git-ai-commit"
            -H "X-Title: git-ai-commit"
        )
    fi

    _http_call "$BASE_URL/chat/completions" "${headers[@]}" -d "$payload"
    if [[ "${LAST_HTTP_STATUS:-000}" != "200" ]]; then
        ui_error "$provider API error (HTTP ${LAST_HTTP_STATUS:-?}):"
        echo "$LAST_RESPONSE_BODY" >&2
        return 1
    fi
    LAST_COMMIT_MESSAGE=$(printf '%s' "$LAST_RESPONSE_BODY" | jq -r '.choices[0].message.content // empty')
    return 0
}

_anthropic_request() {
    local prompt="$1" model="$2"
    local api_key
    api_key=$(resolve_api_key "anthropic")
    if [[ -z "$api_key" ]]; then
        ui_error "API key for anthropic not found. Set ANTHROPIC_API_KEY or pass --api-key."
        return 1
    fi
    require_cmd jq

    local payload
    payload=$(jq -n --arg model "$model" --arg prompt "$prompt" '{
        model: $model,
        max_tokens: 2000,
        messages: [{role: "user", content: $prompt}]
    }')

    _http_call "$BASE_URL/messages" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $api_key" \
        -H "anthropic-version: 2023-06-01" \
        -d "$payload"

    if [[ "${LAST_HTTP_STATUS:-000}" != "200" ]]; then
        ui_error "anthropic API error (HTTP ${LAST_HTTP_STATUS:-?}):"
        echo "$LAST_RESPONSE_BODY" >&2
        return 1
    fi
    LAST_COMMIT_MESSAGE=$(printf '%s' "$LAST_RESPONSE_BODY" \
        | jq -r '.content[]? | select(.type=="text") | .text' | head -n 1)
    return 0
}

# --- Public dispatch --------------------------------------------------------

generate_commit_message() {
    local prompt="$1" model="$2"
    LAST_COMMIT_MESSAGE=""
    case "$PROVIDER" in
        ollama)                    _ollama_request "$prompt" "$model" ;;
        openai|openrouter|minimax) _openai_compatible_request "$prompt" "$model" "$PROVIDER" ;;
        anthropic)                 _anthropic_request "$prompt" "$model" ;;
        *)                         ui_error "Unknown provider: $PROVIDER"; return 1 ;;
    esac
}
