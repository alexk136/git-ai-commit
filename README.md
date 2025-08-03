# git-ai-commit

A shell script that **generates commit messages using a local AI model (Ollama)**, commits changes, pushes them, and **automatically bumps version tags**.

Works even without external dependencies like `jq` and supports **dry-run mode** for testing.

---

## Features

* **AI‑generated commit messages** in [Conventional Commits](https://www.conventionalcommits.org/) format.
* **Ollama integration**: uses a local model (e.g., `gemma:2b` or `llama3:latest`).
* **Automatic version bumping**: `patch`, `minor`, or `major`.
* **Dry‑run mode**: preview generated messages without committing or pushing.
* **No external dependencies** (`jq` not required).

---

## Requirements

* [Ollama](https://ollama.com/) running locally:

  ```bash
  ollama serve
  ```
* A loaded model (default: `gemma:2b`):

  ```bash
  ollama pull gemma:2b
  ```
* Git repository with staged or unstaged changes.

---

## Installation

```bash
chmod +x git-ai-commit.sh
mv git-ai-commit.sh /usr/local/bin/git-ai-commit
```

---

## Usage

### Commit + push + tag:

```bash
git-ai-commit --model gemma:2b --bump patch
```

### Dry‑run (preview only):

```bash
git-ai-commit --model llama3:latest --dry-run
```

### Arguments:

* `--model <name>` – model to use (default: `gemma:2b`).
* `--bump patch|minor|major` – version bump type (default: `patch`).
* `--dry-run` – preview generated message without committing or pushing.
* `--lang <language>` – language for the commit message (default: `english`). Example: `--lang russian` for Russian commit messages.

---

## Example

```bash
$ git-ai-commit --model gemma:2b --bump minor
>>> Generated commit message: fix(auth): handle token refresh
>>> Created new tag: v0.2.0
```

---

## Workflow

1. Checks if Ollama is running and the selected model is loaded.
2. Extracts `git diff` and sends it to the model with a strict commit message prompt.
3. If not in `--dry-run` mode:

   * Adds and commits all changes.
   * Pushes to the current branch.
   * Bumps version tag and pushes the new tag.