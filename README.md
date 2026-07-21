# git-ai-commit

> Generate a commit message with an LLM, commit, and push — optionally bumping
> the semver tag — in one command.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Shellcheck](https://img.shields.io/badge/shellcheck-passing-brightgreen)](bin/git-ai-commit)
[![Tests](https://img.shields.io/badge/tests-bats-blue)](tests/bats)
[![Made with Bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](bin/git-ai-commit)

`git-ai-commit` is a self-contained Bash tool that turns the boring parts of
releasing code into a single command. It picks the right LLM provider
automatically, asks it to summarize your staged changes, commits with a
[Conventional Commits](https://www.conventionalcommits.org/)-style message,
and pushes the branch. Tagging is opt-in: pass `--tag` for one run, or set
`ALWAYS_TAG=1` to make every commit bump the next `vX.Y.Z` tag.

Once installed it adds a `git-commit` command on your `$PATH` (symlink to
`bin/git-ai-commit`). From then on you just run `git-commit`.

```bash
$ export OPENAI_API_KEY=sk-...
$ echo "fix: handle nil" > a.txt
$ git-commit
ℹ Auto-selected provider: openai (from OPENAI_API_KEY)
▶ Sending request to openai model gpt-4o-mini...
>>> Generated message: fix: handle nil pointer in cache loader
✅ Commit pushed (no tag — pass --tag or set ALWAYS_TAG=1 to tag).
```

---

## Features

- **One command, full release** — stage, commit, push, optionally tag.
- **5 LLM providers** — Ollama (local), OpenAI, OpenRouter, Anthropic, MiniMax.
- **Auto-detection** — picks the provider from whichever API key env var is set.
- **Per-repo and global config** — drop a `.gitaicommit` in the repo root or
  `~/.config/git-commit/config` for shared defaults.
- **Environment-variable model overrides** — `<PROVIDER>_MODEL` or
  universal `GAIC_MODEL`.
- **Robust parsing** — handles `<think>` reasoning blocks, common
  AI prefixes, mixed Cyrillic / Latin output, quotes, and stray whitespace.
- **Opt-in tagging** — `--tag` for a single run, `ALWAYS_TAG=1` (env /
  per-repo config) to make every commit bump and push the next semver tag.
- **No required dependencies** beyond `bash`, `git`, `curl`, and optionally
  `jq` (used for non-ollama providers).
- **Single static binary-style entry point** — `bin/git-ai-commit` can be
  symlinked as `git-commit` for system-wide use.

## Table of contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Usage](#usage)
- [Configuration](#configuration)
- [Providers](#providers)
- [How it works](#how-it-works)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Requirements

- **Bash 4+** (uses associative-friendly features; tested on 4.4 through 5.2).
- **Git** with a configured user (name + email).
- **curl** for LLM HTTP calls.
- **jq** — only required when using a non-Ollama provider.
  Install via your package manager (`apt install jq`, `brew install jq`, etc.).
- For local mode: [Ollama](https://ollama.com/) running on
  `http://127.0.0.1:11434` with at least one model pulled.

## Installation

### Dependencies

| OS | Install |
| --- | --- |
| Debian / Ubuntu | `sudo apt install bash git curl jq` |
| Fedora / RHEL | `sudo dnf install bash git curl jq` |
| Alpine | `sudo apk add bash git curl jq` |
| Arch | `sudo pacman -S bash git curl jq` |
| macOS (Homebrew) | `brew install git curl jq` (bash 3.2+ is preinstalled) |

### Install the script

```bash
git clone https://github.com/alexk136/git-ai-commit.git
cd git-ai-commit
./bin/git-ai-commit --install
```

`--install` picks the first writable location from this priority list:

| Platform | Target | Notes |
| --- | --- | --- |
| `--install-dir DIR` | `<DIR>/git-commit` | Explicit override. |
| macOS Apple Silicon + Homebrew | `/opt/homebrew/bin/git-commit` | `$HOMEBREW_PREFIX/bin`. |
| macOS Intel + Homebrew | `/usr/local/bin/git-commit` | Same `HOMEBREW_PREFIX/bin` on this host. |
| Linux (writable `/usr/local/bin`) | `/usr/local/bin/git-commit` | Traditional default. |
| No sudo / read-only `/usr/local/bin` | `~/.local/bin/git-commit` | Hint printed if not on `$PATH`. |

If the chosen directory is not on your `$PATH`, the script prints an
`export PATH=…` hint. To remove: `git-commit --uninstall` (searches all
candidate locations).

### Manual install

```bash
make install                          # autodetect BINDIR (same chain as --install)
make install BINDIR=/custom/path      # explicit
```

### Shell alias (no root needed)

Add to `~/.bashrc` or `~/.zshrc`:

```bash
alias git-commit="$HOME/path/to/git-ai-commit/bin/git-ai-commit"
```

## Quick start

```bash
# 1. Set one (or more) provider API keys
export OPENAI_API_KEY=sk-...
# ...or
export ANTHROPIC_API_KEY=sk-ant-...
# ...or
export OPENROUTER_API_KEY=sk-or-...
# ...or
export MINIMAX_API_KEY=...
# (no key needed for local Ollama)

# 2. Make some changes
echo "new feature" > feature.txt
git add feature.txt

# 3. Run the tool
git-commit
```

The provider is auto-selected from whichever key is set (priority:
openrouter → openai → anthropic → minimax → ollama). By default the tool
commits and pushes without creating a tag. Add `--tag` for a single release
or set `ALWAYS_TAG=1` (env or `.gitaicommit`) to tag every commit. The
first tag for a repo with no prior tag is `v0.1.0`; subsequent tags bump
patch by default.

## Usage

```
git-commit [OPTIONS]
```

### Options

| Flag | Description |
| --- | --- |
| `--provider NAME` | LLM provider: `ollama`, `openai`, `openrouter`, `anthropic`, `minimax` (auto-detected from API key env vars) |
| `--model MODEL` | Model name; defaults per provider, overridable via `<PROVIDER>_MODEL` or `GAIC_MODEL` env vars |
| `--api-key KEY` | API key (else read from `<PROVIDER>_API_KEY` env var) |
| `--base-url URL` | Override the provider's base URL (proxies, self-hosted gateways, etc.) |
| `--bump TYPE` | Version bump: `patch` (default), `minor`, or `major` |
| `--tag [TYPE]` | Also bump and push the next semver tag after commit (equivalent to `ALWAYS_TAG=1` for this run; TYPE in `patch`/`minor`/`major`, default: `patch`) |
| `--lang LANG` | Commit message language: `english` (default) or `russian` |
| `--max-length N` | Max commit message length (default: 200) |
| `--dry-run` | Print the generated message without committing or pushing |
| `--verbose` / `--quiet` | Adjust log level |
| `--install` / `--uninstall` | Symlink / unlink `git-commit` (auto-detects directory) |
| `--install-dir DIR` | With `--install`, override target directory |
| `--help` | Show help |

### Examples

```bash
# Auto-detect provider from env keys
git-commit

# Use a specific provider and model
git-commit --provider openai --model gpt-4o

# Use Anthropic Sonnet
git-commit --provider anthropic --model claude-sonnet-4-5

# Use OpenRouter with any model
git-commit --provider openrouter --model x-ai/grok-4

# MiniMax
git-commit --provider minimax --model MiniMax-M3

# Commit and bump the tag in one go
git-commit --tag

# Commit and bump the minor version tag
git-commit --tag minor

# Always commit + tag (no flag needed)
ALWAYS_TAG=1 git-commit

# Or pin it per-repo via .gitaicommit
echo 'ALWAYS_TAG=1' > .gitaicommit

# Preview only
git-commit --dry-run

# Preview the tag bump without making a commit
git-commit --tag --dry-run

# Russian commit messages
git-commit --lang russian

# Major version bump
git-commit --tag major
```

## Configuration

Configuration is resolved in this order (highest priority first):

1. **CLI flags** — `--provider`, `--model`, `--api-key`, etc.
2. **Environment variables** — `<PROVIDER>_API_KEY`, `<PROVIDER>_MODEL`,
   `GAIC_MODEL`.
3. **Per-repo config** — `<repo>/.gitaicommit` (or `.git-commit`).
4. **Global config** — `$XDG_CONFIG_HOME/git-commit/config`
   (defaults to `~/.config/git-commit/config`).
5. **Built-in defaults**.

### Config file format

A simple `KEY=VALUE` file. Lines starting with `#` are comments, surrounding
quotes are stripped.

```bash
# .gitaicommit — placed at the root of a repo
PROVIDER=openai
MODEL=gpt-4o-mini
LANG=english
BUMP=minor
MAX_COMMIT_MESSAGE_LENGTH=200
```

See [`examples/.gitaicommit.example`](examples/.gitaicommit.example) for a
full sample.

### Recognized keys

| Key | Default | Notes |
| --- | --- | --- |
| `PROVIDER` | `ollama` | One of `ollama`, `openai`, `openrouter`, `anthropic`, `minimax` |
| `MODEL` | per-provider | Provider-specific default (e.g. `gpt-4o-mini` for OpenAI) |
| `BASE_URL` | per-provider | Override the API endpoint |
| `API_KEY` | — | Fallback if no env var is set |
| `BUMP` | `patch` | `patch` \| `minor` \| `major` |
| `LANG` | `english` | `english` \| `russian` |
| `ALWAYS_TAG` | `0` | Always bump and push a tag after commit (`0`/`1`; `true`/`false` also accepted). CLI `--tag` still wins for one run. |
| `MAX_COMMIT_MESSAGE_LENGTH` | `200` | Hard cap; longer messages are truncated |
| `MAX_SIMPLE_MESSAGE_LENGTH` | `100` | Used by the Ollama fallback prompt |
| `CURL_TIMEOUT` | `60` | Per-request timeout in seconds |
| `CURL_CONN_TIMEOUT` | `5` | TCP connect timeout in seconds |
| `CURL_RETRIES` | `2` | Retries on 5xx / transport errors |
| `CURL_RETRY_DELAY` | `1` | Initial retry delay in seconds |
| `CURL_RETRY_BACKOFF` | `2` | Multiplier applied to the retry delay after each attempt |
| `OLLAMA_PROBE_CONNECT_TIMEOUT` | `1` | Ollama reachability probe — connect timeout (seconds) |
| `OLLAMA_PROBE_TIMEOUT` | `2` | Ollama reachability probe — total timeout (seconds) |
| `PROMPT_TEMPLATE_EN` | (English) | LLM prompt for `build_prompt`. Two `%s` placeholders: max length, file summary |
| `PROMPT_TEMPLATE_RU` | (Russian) | LLM prompt for `build_prompt` when `LANG=russian` |
| `PROMPT_FALLBACK_TEMPLATE_EN` | (English) | LLM prompt for `build_fallback_prompt` |
| `PROMPT_FALLBACK_TEMPLATE_RU` | (Russian) | Russian fallback prompt |
| `SEMVER_TAG_PATTERN` | `^v[0-9]+\.[0-9]+\.[0-9]+$` | Regex for matching semver tags |

### Environment variables

| Variable | Purpose |
| --- | --- |
| `<PROVIDER>_API_KEY` | API key (e.g. `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`) |
| `<PROVIDER>_MODEL` | Per-provider model override |
| `GAIC_MODEL` | Universal model override (beats `<PROVIDER>_MODEL`) |
| `ALWAYS_TAG` | `0`/`1` — always bump and push a semver tag after commit |
| `NO_COLOR` | Disable ANSI colors |
| `GAIC_LOG_LEVEL` | `debug` \| `info` \| `warn` \| `error` (default: `info`) |

See [`.env.example`](.env.example) for a ready-to-copy template.

## Providers

| Provider | Type | Default model | Default base URL | Auth |
| --- | --- | --- | --- | --- |
| `ollama` | Local | `mistral-nemo:latest` | `http://127.0.0.1:11434` | none |
| `openai` | Remote | `gpt-4o-mini` | `https://api.openai.com/v1` | `OPENAI_API_KEY` |
| `openrouter` | Aggregator | `anthropic/claude-3.5-haiku` | `https://openrouter.ai/api/v1` | `OPENROUTER_API_KEY` |
| `anthropic` | Remote | `claude-3-5-haiku-latest` | `https://api.anthropic.com/v1` | `ANTHROPIC_API_KEY` |
| `minimax` | Remote | `MiniMax-M3` | `https://api.minimax.io/v1` | `MINIMAX_API_KEY` |

Adding a new provider is a 5-line change in
[`lib/llm.sh`](lib/llm.sh): add a case to
`get_provider_default_model`, `get_provider_default_base_url`, and
`get_provider_env_key`, plus a request function.

## How it works

1. Parse CLI flags and load the config file chain.
2. Auto-detect the provider from env keys if `--provider` isn't given.
3. Check the provider is reachable and (for Ollama) the model is loaded.
4. Build a prompt from `git diff --cached` (falls back to `git diff`, then
   to unpushed commits when there's nothing to commit).
5. Call the LLM with a strict instruction to return only the message.
6. Strip common AI prefixes (`` tags, "Here is a
   commit message:", Cyrillic variants) and surrounding quotes.
7. Truncate to `MAX_COMMIT_MESSAGE_LENGTH` (default 200).
8. `git add -A && git commit && git push`.
9. If `--tag` was passed or `ALWAYS_TAG=1` is set, bump the latest `vX.Y.Z`
   tag and push it; otherwise skip tagging with an info message.

For Ollama only, there's a fallback prompt with a smaller diff window if
the first response is empty.

## Troubleshooting

**`Model X is not loaded in Ollama`**
Pull the model first: `ollama pull mistral-nemo:latest`.

**`API key for openai not found`**
Set `OPENAI_API_KEY` in your shell or pass `--api-key`. To force a
different provider regardless of env, use `--provider`.

**`jq is required for provider X`**
Install `jq`: `apt install jq` / `brew install jq` / `dnf install jq`.

**The generated message is just `` (the model's thinking).**
Your provider's model is reasoning before answering. The script strips
`` blocks automatically, but if the response is empty after
stripping, try a smaller `max_tokens` setting or switch to a
non-reasoning model. For MiniMax-M2.7 specifically, the default
`max_tokens=2000` is enough to fit both thinking and answer.

**Tagging didn't happen even though I expected it.**
Tagging is opt-in now. Either pass `--tag` on the command line, or set
`ALWAYS_TAG=1` in `.env` / `.gitaicommit` to tag every commit. `--dry-run`
also previews the tag if `--tag` is set, no LLM required.

**`command not found: git-commit` after `--install`**
You need write access to `/usr/local/bin`. Re-run with `sudo` or add
the alias to `~/.bashrc`.

## Project layout

```
.
├── bin/
│   └── git-ai-commit          # entry point
├── lib/                       # sourced modules
│   ├── ui.sh                  # colored output, errors
│   ├── config.sh              # config file loader, validation
│   ├── tags.sh                # semver tag math
│   ├── git.sh                 # git plumbing helpers
│   ├── llm.sh                 # LLM provider abstraction
│   └── prompt.sh              # prompt building + cleanup
├── tests/
│   └── bats/                  # bats-core unit + integration tests
├── examples/
│   └── .gitaicommit.example   # sample per-repo config
├── .env.example               # sample env file
├── .github/
│   ├── workflows/ci.yml       # shellcheck + bats
│   ├── ISSUE_TEMPLATE/        # bug + feature templates
│   └── PULL_REQUEST_TEMPLATE.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── SECURITY.md
└── LICENSE
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow, coding style, and
how to run the test suite locally. Issues and PRs are welcome.

## License

[MIT](LICENSE) © 2025 git-ai-commit contributors
