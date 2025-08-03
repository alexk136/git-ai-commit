#!/bin/bash
set -e


MODEL="gemma:2b"
BUMP="patch"
OLLAMA_URL="http://127.0.0.1:11434"
DRY_RUN=false
LANG="english"

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
    case $1 in
        --model)
            MODEL="$2"
            shift 2
            ;;
        --bump)
            BUMP="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift 1
            ;;
        --lang)
            LANG="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# --- Проверка Ollama ---
if ! curl -s --connect-timeout 1 "$OLLAMA_URL" > /dev/null; then
    echo "❌ Ollama сервер не запущен на $OLLAMA_URL"
    exit 0
fi

# --- Проверка модели ---
# --- Model check ---
if ! curl -s "$OLLAMA_URL/api/tags" | grep -q "\"name\":\"$MODEL\""; then
    echo "❌ Модель $MODEL не загружена в Ollama"
    exit 0
fi

# --- Ollama check ---
if ! curl -s --connect-timeout 1 "$OLLAMA_URL" > /dev/null; then
    echo "❌ Ollama server is not running at $OLLAMA_URL"
    exit 0
fi

# --- Model check ---
if ! curl -s "$OLLAMA_URL/api/tags" | grep -q "\"name\":\"$MODEL\""; then
    echo "❌ Model $MODEL is not loaded in Ollama"
    exit 0
fi

# --- Get diff ---
diff_output=$(git diff --cached)
if [ -z "$diff_output" ]; then
    # Check for untracked files
    untracked_files=$(git ls-files --others --exclude-standard)
    if [ -z "$untracked_files" ]; then
        # Check for unstaged changes
        unstaged_changes=$(git diff)
        if [ -z "$unstaged_changes" ]; then
            echo "No changes to commit"
            exit 0
        else
            diff_output="$unstaged_changes"
        fi
    else
        # Get diff of untracked files
        diff_output=""
        for file in $untracked_files; do
            diff_output="$diff_output$(echo "New file: $file"; cat "$file"; echo)"
        done
    fi
fi

# --- Generate commit message ---
# Simplify the diff for JSON safety
simple_diff=$(echo "$diff_output" | head -5 | tr -cd '[:alnum:][:space:]._-' | tr '\n' ' ')

response=$(curl -s "$OLLAMA_URL/api/generate" \
  -H "Content-Type: application/json" \
  -d "{\"model\": \"$MODEL\", \"prompt\": \"Write a short conventional commit message (max 60 chars) in $LANG language for: $simple_diff\", \"stream\": false}")

# --- Parse response ---
commit_message=$(echo "$response" | grep -o '"response":"[^"]*"' | sed 's/"response":"//;s/"$//' | tr -d '\n')
commit_message=$(echo "$commit_message" | xargs) # remove extra spaces

if [ -z "$commit_message" ]; then
    echo "❌ Failed to get commit message from model"
    exit 1
fi

echo ">>> Generated message: $commit_message"

# --- Dry-run mode ---
if [ "$DRY_RUN" = true ]; then
    echo "Dry-run: changes will not be committed and pushed."
    exit 0
fi

# --- Commit and push ---
git add -A
git commit -m "$commit_message"
git push

# --- Tag increment ---
git fetch --tags
last_tag=$(git tag --sort=-v:refname | head -n 1)
if [ -z "$last_tag" ]; then
    major=0; minor=1; patch=0
else
    version=${last_tag#v}
    IFS='.' read -r major minor patch <<< "$version"
fi

case $BUMP in
    major) major=$((major + 1)); minor=0; patch=0 ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    patch) patch=$((patch + 1)) ;;
esac

new_tag="v${major}.${minor}.${patch}"
git tag "$new_tag"
git push origin "$new_tag"

echo ">>> New tag created: $new_tag"
echo "✅ Commit and tag successfully created and pushed."