# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Tagging is now **opt-in**. `git-ai-commit` (no flag) commits and pushes
  without creating a tag. Pass `--tag` to bump and push the next semver tag
  on a single run, or set `ALWAYS_TAG=1` (env or `.gitaicommit`) to make
  every commit tag. The previous "tag-only mode" (`--tag` without a
  commit) is removed.

### Added
- New `ALWAYS_TAG` config key / env var (`0`/`1`/`true`/`false`) in
  `lib/config.sh` `CONFIG_KEYS`. Documented in `.env.example`,
  `examples/.gitaicommit.example`, and `README.md`.
- `--install` now auto-detects the target directory: explicit
  `--install-dir DIR` → `$HOMEBREW_PREFIX/bin` → `/usr/local/bin` →
  `~/.local/bin`. New `--install-dir DIR` flag overrides the chain. Prints
  a `PATH` hint if the chosen dir is not on `$PATH`. `--uninstall`
  searches all candidate locations. Makefile `install` target also
  auto-detects `BINDIR` the same way.
- Translate remaining Russian UI strings: `lib/git.sh`'s
  `require_clean_working_tree` error message and the Ollama-down
  fallback strings in `bin/git-ai-commit` are now English. Russian
  prompt templates in `lib/prompt.sh` are kept (intentional — they
  steer the LLM when `LANG=russian`).
- New env vars surface previously hardcoded settings through `.env` /
  `.gitaicommit`: `CURL_CONN_TIMEOUT`, `CURL_RETRY_DELAY`,
  `CURL_RETRY_BACKOFF`, `OLLAMA_PROBE_CONNECT_TIMEOUT`,
  `OLLAMA_PROBE_TIMEOUT`, `PROMPT_TEMPLATE_EN`, `PROMPT_TEMPLATE_RU`,
  `PROMPT_FALLBACK_TEMPLATE_EN`, `PROMPT_FALLBACK_TEMPLATE_RU`,
  `SEMVER_TAG_PATTERN`. `CURL_CONN_TIMEOUT` is now part of
  `CONFIG_KEYS` so it loads from per-repo config.
- `lib/prompt.sh` now passes the **entire git diff** to the LLM instead
  of just file headers. Previously the model only saw a 10-line
  `file_summary` (paths + `+++`/`---`) and had to guess the message —
  fine for one-line changes, useless for anything structural. The full
  diff gives it enough context to write meaningful messages. Updated
  default `PROMPT_TEMPLATE_EN` / `PROMPT_TEMPLATE_RU` wording to
  match.
- Default `MAX_COMMIT_MESSAGE_LENGTH` raised `200` → `500`,
  `MAX_SIMPLE_MESSAGE_LENGTH` raised `100` → `1000`. Longer messages
  produced by the LLM are still truncated to the cap before commit.
- Dropped dead code (`files_changed` count in `build_prompt` was
  computed but never used).

## [0.3.0] - 2025-XX-XX

### Added
- Multi-provider support: Ollama, OpenAI, OpenRouter, Anthropic, MiniMax.
- Auto-detect provider from env vars (`OPENAI_API_KEY`, `OPENROUTER_API_KEY`,
  `ANTHROPIC_API_KEY`, `MINIMAX_API_KEY`) with priority order
  openrouter → openai → anthropic → minimax → ollama.
- Per-provider model env var (`OPENAI_MODEL`, `ANTHROPIC_MODEL`, etc.) and
  universal `GAIC_MODEL` override.
- Per-repo config file (`.gitaicommit`) and global config
  (`~/.config/git-commit/config`) with `KEY=VALUE` syntax.
- `bats` test suite covering UI, tags, prompt, config, CLI, and LLM modules.
- `--install` / `--uninstall` for `/usr/local/bin/git-commit` symlink.
- `--verbose` / `--quiet` log level control.
- `--max-length` to override the commit message length cap.
- Color output with `NO_COLOR` support.
- Retry with exponential backoff on transient HTTP/transport errors.
- `.env.example` template.
- `examples/.gitaicommit.example` sample.
- CI: shellcheck + bats on push and PR.

### Changed
- Refactored from a single 600-line script into `bin/git-ai-commit` + 6
  modules under `lib/`.
- Improved cleanup: strips `` blocks, common AI prefixes, Cyrillic
  variants, surrounding quotes, and collapses whitespace.
- Increased `max_tokens` from 300 to 2000 so reasoning models (e.g.
  MiniMax-M2.7) have room to finish after the thinking phase.
- Bumped default model to `mistral-nemo:latest`.

### Fixed
- `lib/prompt.sh`: cleanup_message no longer breaks on multi-line
  `` blocks.
- `lib/config.sh`: `config_file_lookup` now correctly handles Cyrillic
  prefixes.
- Argument parsing no longer leaves the wrapper UI functions without
  forwarding `"$@"`.
- Order of operations in `resolve_config` no longer overwrites
  per-repo config settings with built-in defaults.

## [0.2.x] - earlier

Pre-refactor releases. See git history.
