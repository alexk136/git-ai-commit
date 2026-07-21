#!/usr/bin/env bash
# shellcheck shell=bash
# lib/prompt.sh — build the LLM prompt from a git diff.

if [[ -n "${__GAIC_PROMPT_LOADED:-}" ]]; then
    return 0
fi
__GAIC_PROMPT_LOADED=1

# build_prompt <diff_text> <language> <max_length>
# Prints the prompt to stdout. Language is "russian" or anything else (english).
# The full diff is passed to the LLM so it can actually see what changed.
build_prompt() {
    local diff="$1" lang="$2" max_len="$3"

    local tmpl
    if [[ "$lang" == "russian" ]]; then
        tmpl="${PROMPT_TEMPLATE_RU:-Сгенерируй только сообщение коммита (максимум %s символов) на русском языке для следующего diff: %s. Ответь только сообщением без дополнительного текста.}"
    else
        tmpl="${PROMPT_TEMPLATE_EN:-Generate only a commit message (max %s chars) in English for the following diff: %s. Reply with only the message, no extra text.}"
    fi
    # shellcheck disable=SC2059  # tmpl is operator-provided; literal defaults are safe
    printf "$tmpl" "$max_len" "$diff"
}

# build_fallback_prompt <diff_text> <language> <max_length>
# Simpler prompt used when the primary one returns an empty response.
# Still passes the full diff so the model has a second chance to see the
# changes; the model is asked for a shorter message than the primary prompt.
build_fallback_prompt() {
    local diff="$1" lang="$2" max_len="$3"

    local tmpl
    if [[ "$lang" == "russian" ]]; then
        tmpl="${PROMPT_FALLBACK_TEMPLATE_RU:-Только сообщение коммита (до %s символов): %s}"
    else
        tmpl="${PROMPT_FALLBACK_TEMPLATE_EN:-Only commit message (under %s chars): %s}"
    fi
    # shellcheck disable=SC2059  # tmpl is operator-provided; literal defaults are safe
    printf "$tmpl" "$max_len" "$diff"
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
