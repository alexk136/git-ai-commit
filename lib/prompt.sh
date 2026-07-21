#!/usr/bin/env bash
# shellcheck shell=bash
# lib/prompt.sh — build the LLM prompt from a git diff.

if [[ -n "${__GAIC_PROMPT_LOADED:-}" ]]; then
    return 0
fi
__GAIC_PROMPT_LOADED=1

# build_prompt <diff_text> <language> <max_length>
# Prints the prompt to stdout. The <language> argument is kept for API
# stability but is currently a no-op — there is no per-language template
# anymore (PROMPT_TEMPLATE is the single configurable string). The full
# diff is passed to the LLM so it can actually see what changed.
build_prompt() {
    local diff="$1" _lang="$2" max_len="$3"

    local tmpl="${PROMPT_TEMPLATE:-Generate only a commit message (max %s chars) in English for the following diff: %s. Reply with only the message, no extra text.}"
    # shellcheck disable=SC2059  # tmpl is operator-provided; literal defaults are safe
    printf "$tmpl" "$max_len" "$diff"
}

# build_fallback_prompt <diff_text> <language> <max_length>
# Simpler prompt used when the primary one returns an empty response.
# The <language> argument is a no-op (see build_prompt).
build_fallback_prompt() {
    local diff="$1" _lang="$2" max_len="$3"

    local tmpl="${PROMPT_FALLBACK_TEMPLATE:-Only commit message (under %s chars): %s}"
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
