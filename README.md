# git-ai-commit

A shell script that **generates commit messages using a local AI model (Ollama)**, commits changes, pushes them, and **automatically bumps version tags**.

Works even without external dependencies like `jq` and supports **dry-run mode** for testing.

---

## Features

* **AI‑generated commit messages** in [Conventional Commits](https://www.conventionalcommits.org/) format.
* **Ollama integration**: uses a local model (e.g., `llama3:latest` or `llama3:latest`).
* **Automatic version bumping**: `patch`, `minor`, or `major`.
* **Dry‑run mode**: preview generated messages without committing or pushing.
* **No external dependencies** (`jq` not required).
* **Global installation**: easy setup with `--register` flag.

---

## Requirements

* [Ollama](https://ollama.com/) running locally:

  ```bash
  ollama serve
  ```
* A loaded model (default: `llama3:latest`):

  ```bash
  ollama pull llama3:latest
  ```
* Git repository with staged or unstaged changes.

---

## Installation

### Quick Setup (Recommended)

1. Clone this repository:
   ```bash
   git clone https://github.com/alexk136/git-ai-commit.git
   cd git-ai-commit
   ```

2. Register commands globally:
   ```bash
   ./git-ai-commit.sh --register
   ./git-tag.sh --register
   ```

That's it! Now you can use `git-ai-commit` and `git-tag-bump` from any directory.

### Manual Installation

```bash
chmod +x git-ai-commit.sh git-tag.sh
sudo ln -sf "$(pwd)/git-ai-commit.sh" /usr/local/bin/git-ai-commit
sudo ln -sf "$(pwd)/git-tag.sh" /usr/local/bin/git-tag-bump
```

---

## Usage

### Commit + push + tag:

```bash
git-ai-commit --model llama3:latest --bump patch
```

### Only create and push tag (no commit):

```bash
git-ai-commit --tag           # Increase patch: v0.1.2 → v0.1.3
git-ai-commit --tag minor     # Increase minor: v0.1.2 → v0.2.0
git-ai-commit --tag major     # Increase major: v0.1.2 → v1.0.0
```

### Dry‑run (preview only):

```bash
git-ai-commit --model llama3:latest --dry-run
git-ai-commit --tag --dry-run        # Preview patch increment
git-ai-commit --tag major --dry-run  # Preview major increment
```

### Arguments:

* `--model <name>` – model to use (default: `llama3:latest`).
* `--bump patch|minor|major` – version bump type (default: `patch`).
* `--dry-run` – preview generated message without committing or pushing.
* `--tag [TYPE]` – work only with tags: patch|minor|major (default: patch).
* `--lang <language>` – language for the commit message (default: `english`). Example: `--lang russian` for Russian commit messages.
* `--register` – register command globally for system-wide access.
* `--help` – show usage information.

---

## Example

```bash
# Full workflow: AI commit + tag
$ git-ai-commit --model llama3:latest --bump minor
>>> Generated commit message: fix(auth): handle token refresh
>>> New tag created: v0.2.0
✅ Commit and tag successfully created and pushed.

# Only tag creation
$ git-ai-commit --tag major
🏷️  Работаем только с тегами...
>>> New tag created: v1.0.0
✅ Тег успешно создан и отправлен.

# Preview mode
$ git-ai-commit --tag --dry-run
🏷️  Работаем только с тегами...
>>> Dry-run: новый тег будет: v0.1.3
```

---

## Workflow

1. Checks if Ollama is running and the selected model is loaded.
2. Extracts `git diff` and sends it to the model with a strict commit message prompt.
3. If not in `--dry-run` mode:

   * Adds and commits all changes.
   * Pushes to the current branch.
   * Bumps version tag and pushes the new tag.