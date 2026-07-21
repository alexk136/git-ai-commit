#!/usr/bin/env bash
# shellcheck shell=bash
# lib/prompt.sh — build the LLM prompt from a git diff.

if [[ -n "${__GAIC_PROMPT_LOADED:-}" ]]; then
    return 0
fi
__GAIC_PROMPT_LOADED=1

# build_prompt <diff_text> <language> <max_length>
# Prints the prompt to stdout. Language is "russian" or anything else (english).
build_prompt() {
    local diff="$1" lang="$2" max_len="$3"

    local files_changed
    files_changed=$(printf '%s\n' "$diff" | grep -c '^diff --git' || true)
    if [[ "$files_changed" -eq 0 ]]; then
        files_changed=$(printf '%s\n' "$diff" | grep -c '^New file:' || true)
    fi

    local file_summary
    file_summary=$(printf '%s\n' "$diff" \
        | grep -E '^(diff --git|New file:|\+\+\+|---)' \
        | head -10 | tr '\n' ' ')

    local tmpl
    if [[ "$lang" == "russian" ]]; then
        tmpl="${PROMPT_TEMPLATE_RU:-Сгенерируй только сообщение коммита (максимум %s символов) на русском языке для изменений в файлах: %s. Ответь только сообщением без дополнительного текста.}"
    else
        tmpl="${PROMPT_TEMPLATE_EN:-Generate only a commit message (max %s chars) in English for file changes: %s. Reply with only the message, no extra text.}"
    fi
    # shellcheck disable=SC2059  # tmpl is operator-provided; literal defaults are safe
    printf "$tmpl" "$max_len" "$file_summary"
}

# build_fallback_prompt <diff_text> <language> <max_length>
# Simpler prompt used when the primary one returns an empty response.
build_fallback_prompt() {
    local diff="$1" lang="$2" max_len="$3"
    local simple_diff
    simple_diff=$(printf '%s\n' "$diff" | head -3 | tr -cd '[:alnum:][:space:]._-' | tr '\n' ' ')

    local tmpl
    if [[ "$lang" == "russian" ]]; then
        tmpl="${PROMPT_FALLBACK_TEMPLATE_RU:-Только сообщение коммита (до %s символов): %s}"
    else
        tmpl="${PROMPT_FALLBACK_TEMPLATE_EN:-Only commit message (under %s chars): %s}"
    fi
    # shellcheck disable=SC2059  # tmpl is operator-provided; literal defaults are safe
    printf "$tmpl" "$max_len" "$simple_diff"
}

# cleanup_message <raw_message>
# Strip common AI prefixes, <think>...</think> reasoning blocks, surrounding
# quotes, and extra whitespace. Leaves the first line of clean text.
cleanup_message() {
    local msg="$1"
    # Drop reasoning/thinking blocks (MiniMax-M2.7 emits <think>...</think> in content).
    # sed .* doesn't span newlines; collapse newlines first.
    msg=$(printf '%s' "$msg" | tr '\n' ' ' | sed 's/<think>.*<\/think>//')
    # Strip common AI prefixes
    msg=$(printf '%s' "$msg" \
        | sed 's/^[Hh]ere is a[^:]*: *//i' \
        | sed 's/^[Cc]ommit message: *//i' \
        | sed 's/^[Сс]ообщение коммита: *//')
    # Collapse whitespace, drop surrounding quotes, keep only first line
    msg=$(printf '%s' "$msg" \
        | tr '\n' ' ' \
        | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/\\$//; s/"$//; s/^"//; s/  */ /g' \
        | head -n 1)
    printf '%s' "$msg"
}
