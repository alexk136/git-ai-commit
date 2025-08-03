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
            # Проверяем, есть ли следующий аргумент и это не флаг
            if [[ $# -gt 1 && ! "$2" =~ ^-- ]]; then
                BUMP="$2"
                shift 2
            else
                BUMP="patch"  # по умолчанию patch
                shift 1
            fi
            ;;
        --register)
            echo "🔧 Регистрируем команду git-ai-commit глобально..."
            
            # Получаем абсолютный путь к скрипту
            SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
            
            # Проверяем права на запись в /usr/local/bin
            if [ -w /usr/local/bin ]; then
                ln -sf "$SCRIPT_PATH" /usr/local/bin/git-ai-commit
                echo "✅ Команда git-ai-commit успешно зарегистрирована!"
                echo "💡 Теперь вы можете использовать 'git-ai-commit' из любой папки"
            else
                echo "🔐 Требуются права администратора для регистрации команды:"
                echo "sudo ln -sf '$SCRIPT_PATH' /usr/local/bin/git-ai-commit"
                echo ""
                echo "Или добавьте эту команду в ваш ~/.bashrc:"
                echo "alias git-ai-commit='$SCRIPT_PATH'"
            fi
            exit 0
            ;;
        --help)
            echo "Git AI Commit - автоматическая генерация commit сообщений"
            echo ""
            echo "Использование: $0 [OPTIONS]"
            echo ""
            echo "Опции:"
            echo "  --model MODEL     Модель Ollama (по умолчанию: llama3:latest)"
            echo "  --bump TYPE       Тип версии: major|minor|patch (по умолчанию: patch)"
            echo "  --dry-run         Показать сообщение без коммита"
            echo "  --lang LANG       Язык сообщения (по умолчанию: english)"
            echo "  --tag [TYPE]      Работать только с тегами: patch|minor|major (по умолчанию: patch)"
            echo "  --register        Зарегистрировать команду глобально"
            echo "  --help            Показать эту справку"
            echo ""
            echo "Примеры:"
            echo "  $0                           # Базовое использование"
            echo "  $0 --model llama2 --dry-run # Тест с другой моделью"
            echo "  $0 --bump minor              # Увеличить minor версию"
            echo "  $0 --tag                     # Увеличить patch тег"
            echo "  $0 --tag minor               # Увеличить minor тег"
            echo "  $0 --tag major               # Увеличить major тег"
            echo "  $0 --register                # Зарегистрировать команду"
            exit 0
            ;;
        *)
            echo "Неизвестный аргумент: $1"
            echo "Используйте --help для справки"
            exit 1
            ;;
    esac
done

# --- Режим только тегов ---
if [ "$TAG_ONLY" = true ]; then
    echo "🏷️  Работаем только с тегами..."
    
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
        echo ">>> Dry-run: новый тег будет: $new_tag"
        exit 0
    fi
    
    git tag "$new_tag"
    git push origin "$new_tag"
    
    echo ">>> New tag created: $new_tag"
    echo "✅ Тег успешно создан и отправлен."
    exit 0
fi

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
simple_diff=$(echo "$diff_output" | head -3 | tr -cd '[:alnum:][:space:]._-' | tr '\n' ' ')

echo "🔍 Отправляем запрос к модели $MODEL..."

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
    echo "🔄 Пробуем альтернативный промпт..."
    response=$(curl -s -w "HTTP_STATUS:%{http_code}" "$OLLAMA_URL/api/generate" \
      -H "Content-Type: application/json" \
      -d "{\"model\": \"$MODEL\", \"prompt\": \"Generate a short git commit message (under 50 characters) for: $simple_diff\", \"stream\": false}")
    
    http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    response_body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')
    
    if [ "$http_status" != "200" ]; then
        echo "❌ Ошибка при втором запросе (HTTP $http_status):"
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