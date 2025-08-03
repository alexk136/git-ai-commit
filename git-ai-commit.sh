#!/bin/bash
set -e


MODEL="llama3:latest"
BUMP="patch"
OLLAMA_URL="http://127.0.0.1:11434"
DRY_RUN=false
LANG="english"
TAG_ONLY=false

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
        --tag)
            TAG_ONLY=true
            # Check if the next argument exists and is not a flag
            if [[ $# -gt 1 && ! "$2" =~ ^-- ]]; then
                BUMP="$2"
                shift 2
            else
                BUMP="patch"  # default is patch
                shift 1
            fi
            ;;
        --register)
            echo "🔧 Registering git-ai-commit command globally..."
            
            # Get the absolute path to the script
            SCRIPT_PATH="$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)/$(basename \"${BASH_SOURCE[0]}\")"
            
            # Check write permissions for /usr/local/bin
            if [ -w /usr/local/bin ]; then
                ln -sf "$SCRIPT_PATH" /usr/local/bin/git-ai-commit
                echo "✅ git-ai-commit command successfully registered!"
                echo "💡 Now you can use 'git-ai-commit' from any folder"
            else
                echo "🔐 Administrator rights are required to register the command:"
                echo "sudo ln -sf '$SCRIPT_PATH' /usr/local/bin/git-ai-commit"
                echo ""
                echo "Or add this command to your ~/.bashrc:"
                echo "alias git-ai-commit='$SCRIPT_PATH'"
            fi
            exit 0
            ;;
        --help)
            echo "Git AI Commit - automatic commit message generation"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --model MODEL     Ollama model (default: llama3:latest)"
            echo "  --bump TYPE       Version type: major|minor|patch (default: patch)"
            echo "  --dry-run         Show message without committing"
            echo "  --lang LANG       Message language (default: english)"
            echo "  --tag [TYPE]      Work only with tags: patch|minor|major (default: patch)"
            echo "  --register        Register command globally"
            echo "  --help            Show this help"
            echo ""
            echo "Examples:"
            echo "  $0                           # Basic usage"
            echo "  $0 --model llama2 --dry-run # Test with another model"
            echo "  $0 --bump minor              # Increment minor version"
            echo "  $0 --tag                     # Increment patch tag"
            echo "  $0 --tag minor               # Increment minor tag"
            echo "  $0 --tag major               # Increment major tag"
            echo "  $0 --register                # Register command"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Use --help for help"
            exit 1
            ;;
    esac
done

# --- Tag-only mode ---
if [ "$TAG_ONLY" = true ]; then
    echo "🏷️  Working with tags only..."
    
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
    
    if [ "$DRY_RUN" = true ]; then
        echo ">>> Dry-run: new tag will be: $new_tag"
        exit 0
    fi
    
    git tag "$new_tag"
    git push origin "$new_tag"
    
    echo ">>> New tag created: $new_tag"
    echo "✅ Tag successfully created and pushed."
    exit 0
fi

# --- Проверка Ollama ---
if ! curl -s --connect-timeout 1 "$OLLAMA_URL" > /dev/null; then
    echo "❌ Ollama server is not running at $OLLAMA_URL"
    exit 0
fi

if ! curl -s "$OLLAMA_URL/api/tags" | grep -q "\"name\":\"$MODEL\""; then
    echo "❌ Model $MODEL is not loaded in Ollama"
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
simple_diff=$(echo "$diff_output" | head -3 | tr -cd '[:alnum:][:space:]._-' | tr '\n' ' ')

echo "🔍 Sending request to model $MODEL..."

# Try to get a commit message from the model with a very direct prompt
response=$(curl -s -w "HTTP_STATUS:%{http_code}" "$OLLAMA_URL/api/generate" \
  -H "Content-Type: application/json" \
  -d "{\"model\": \"$MODEL\", \"prompt\": \"Write a concise git commit message (max 100 chars) for this diff: $simple_diff\n\nCommit message:\", \"stream\": false}")

# Extract HTTP status and response body
http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
response_body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')

echo "🌐 HTTP Status: $http_status"

if [ "$http_status" != "200" ]; then
    echo "❌ Ошибка от Ollama (HTTP $http_status):"
    echo "$response_body"
    exit 1
fi

# --- Parse response ---
# Extract the response content, handling escaped quotes
commit_message=$(echo "$response_body" | sed 's/.*"response":"\([^"]*\)".*/\1/' | sed 's/\\"/"/g')

# If that extracted just a backslash, try a different approach  
if [ "$commit_message" = "\\" ] || [ -z "$commit_message" ]; then
    # Handle cases where the response contains escaped quotes
    commit_message=$(echo "$response_body" | sed 's/.*"response":"\\*"\([^"]*\)\\*"".*/\1/')
fi

# Clean up and trim
commit_message=$(echo "$commit_message" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/\\$//; s/"$//' | head -n 1)

# If still empty, try a different approach
if [ -z "$commit_message" ]; then
    echo "🔄 Trying alternative prompt..."
    response=$(curl -s -w "HTTP_STATUS:%{http_code}" "$OLLAMA_URL/api/generate" \
      -H "Content-Type: application/json" \
      -d "{\"model\": \"$MODEL\", \"prompt\": \"Generate a short git commit message (under 50 characters) for: $simple_diff\", \"stream\": false}")
    
    http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    response_body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')
    
    if [ "$http_status" != "200" ]; then
        echo "❌ Error on second request (HTTP $http_status):"
        echo "$response_body"
        exit 1
    fi
    
    commit_message=$(echo "$response_body" | grep -o '"response":"[^"]*"' | sed 's/"response":"//;s/"$//' | tr -d '\n')
    commit_message=$(echo "$commit_message" | head -n 1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
fi

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