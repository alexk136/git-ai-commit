#!/bin/bash
set -e

# --- Constants ---
MAX_COMMIT_MESSAGE_LENGTH=102    # Maximum allowed length for commit messages
TRUNCATED_MESSAGE_LENGTH=99     # Length limit for truncation (leaving space for "...")
MAX_SIMPLE_MESSAGE_LENGTH=50    # Maximum length for fallback simple prompts

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
            echo "🔧 Registering git-commit command globally..."
            
            # Get the absolute path to the script
            SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
            
            # Check write permissions for /usr/local/bin
            if [ -w /usr/local/bin ]; then
                ln -sf "$SCRIPT_PATH" /usr/local/bin/git-commit
                echo "✅ git-commit command successfully registered!"
                echo "💡 Now you can use 'git-commit' from any folder"
            else
                echo "🔐 Administrator rights are required to register the command:"
                echo "sudo ln -sf \"$SCRIPT_PATH\" /usr/local/bin/git-commit"
                echo ""
                echo "Or add this command to your ~/.bashrc:"
                echo "alias git-commit=\"$SCRIPT_PATH\""
            fi
            exit 0
            ;;
        --uninstall)
            echo "🗑️  Uninstalling git-commit command..."
            
            # Check if symlink exists in /usr/local/bin
            if [ -L /usr/local/bin/git-commit ]; then
                if [ -w /usr/local/bin ]; then
                    rm /usr/local/bin/git-commit
                    echo "✅ git-commit command successfully uninstalled!"
                else
                    echo "🔐 Administrator rights are required to uninstall the command:"
                    echo "sudo rm /usr/local/bin/git-commit"
                fi
            else
                echo "ℹ️  git-commit command is not installed globally"
                echo "💡 If you used alias in ~/.bashrc, remove this line manually:"
                echo "alias git-commit='$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)/$(basename \"${BASH_SOURCE[0]}\")'"
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
            echo "  --uninstall       Uninstall globally registered command"
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
            echo "  $0 --uninstall               # Uninstall command"
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
            # Check for unpushed commits
            unpushed_commits=$(git log origin/$(git branch --show-current)..HEAD --oneline 2>/dev/null || echo "")
            if [ -n "$unpushed_commits" ]; then
                echo "📦 Found unpushed commits. Creating tag only..."
                echo "Unpushed commits:"
                echo "$unpushed_commits"
                
                # Skip to tag creation
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
                
                if [ "$DRY_RUN" = true ]; then
                    echo ">>> Dry-run: would push commits and create tag: $new_tag"
                    exit 0
                fi
                
                git tag "$new_tag"
                git push origin "$new_tag"
                
                echo ">>> New tag created: $new_tag"
                echo "✅ Commits pushed and tag successfully created."
                exit 0
            else
                echo "No changes to commit"
                exit 0
            fi
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
# Get a more meaningful summary of changes
files_changed=$(echo "$diff_output" | grep "^diff --git" | wc -l)
if [ "$files_changed" -eq 0 ]; then
    files_changed=$(echo "$diff_output" | grep "^New file:" | wc -l)
fi

# Extract file names and change types
file_summary=$(echo "$diff_output" | grep -E "^(diff --git|New file:|\+\+\+|---)" | head -10 | tr '\n' ' ')
# Get some actual code changes for context
code_changes=$(echo "$diff_output" | grep -E "^[+-]" | grep -v "^[+-][+-][+-]" | head -5 | tr '\n' ' ')

# Create a better prompt with more context
if [ "$LANG" = "russian" ]; then
    prompt="Сгенерируй только сообщение коммита (максимум $MAX_COMMIT_MESSAGE_LENGTH символов) на русском языке для изменений в файлах: $file_summary. Ответь только сообщением без дополнительного текста."
else
    prompt="Generate only a commit message (max $MAX_COMMIT_MESSAGE_LENGTH chars) in English for file changes: $file_summary. Reply with only the message, no extra text."
fi

echo "🔍 Sending request to model $MODEL..."

# Clean the prompt for JSON safety
clean_prompt=$(echo "$prompt" | tr '\n' ' ' | sed 's/"/\\"/g')

# Try to get a commit message from the model with better context
response=$(curl -s -w "HTTP_STATUS:%{http_code}" "$OLLAMA_URL/api/generate" \
  -H "Content-Type: application/json" \
  -d "{\"model\": \"$MODEL\", \"prompt\": \"$clean_prompt\", \"stream\": false}")

# Extract HTTP status and response body
http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
response_body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')

echo "🌐 HTTP Status: $http_status"

if [ "$http_status" != "200" ]; then
    echo "❌ Error from Ollama (HTTP $http_status):"
    echo "$response_body"
    exit 1
fi

# --- Parse response ---
# Extract the response content, handling escaped quotes
commit_message=$(echo "$response_body" | sed 's/.*"response":"\([^"]*\)".*/\1/' | sed 's/\\"/"/g' | sed 's/\\n/ /g')

# Clean up common AI response patterns
commit_message=$(echo "$commit_message" | sed 's/^[Hh]ere is a[^:]*: *//i' | sed 's/^[Cc]ommit message: *//i' | sed 's/^[Ss]ообщение коммита: *//i')

# If that extracted just a backslash, try a different approach  
if [ "$commit_message" = "\\" ] || [ -z "$commit_message" ]; then
    # Handle cases where the response contains escaped quotes
    commit_message=$(echo "$response_body" | sed 's/.*"response":"\\*"\([^"]*\)\\*"".*/\1/')
fi

# Clean up and trim - remove newlines, extra spaces, quotes
commit_message=$(echo "$commit_message" | tr '\n' ' ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/\\$//; s/"$//; s/^"//; s/  */ /g' | head -n 1)

# Truncate if too long
if [ ${#commit_message} -gt $MAX_COMMIT_MESSAGE_LENGTH ]; then
    commit_message=$(echo "$commit_message" | cut -c1-$TRUNCATED_MESSAGE_LENGTH)...
fi

# If still empty, try a different approach
if [ -z "$commit_message" ]; then
    echo "🔄 Trying alternative prompt..."
    
    # Fallback with simpler prompt
    simple_diff=$(echo "$diff_output" | head -3 | tr -cd '[:alnum:][:space:]._-' | tr '\n' ' ')
    
    if [ "$LANG" = "russian" ]; then
        fallback_prompt="Только сообщение коммита (до $MAX_SIMPLE_MESSAGE_LENGTH символов): $simple_diff"
    else
        fallback_prompt="Only commit message (under $MAX_SIMPLE_MESSAGE_LENGTH chars): $simple_diff"
    fi
    
    response=$(curl -s -w "HTTP_STATUS:%{http_code}" "$OLLAMA_URL/api/generate" \
      -H "Content-Type: application/json" \
      -d "{\"model\": \"$MODEL\", \"prompt\": \"$fallback_prompt\", \"stream\": false}")
    
    http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    response_body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')
    
    if [ "$http_status" != "200" ]; then
        echo "❌ Error on second request (HTTP $http_status):"
        echo "$response_body"
        exit 1
    fi
    
    commit_message=$(echo "$response_body" | grep -o '"response":"[^"]*"' | sed 's/"response":"//;s/"$//' | tr -d '\n' | sed 's/\\n/ /g')
    commit_message=$(echo "$commit_message" | sed 's/^[Hh]ere is a[^:]*: *//i' | sed 's/^[Cc]ommit message: *//i' | head -n 1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
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