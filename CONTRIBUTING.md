# Contributing to git-commit

Thanks for your interest in contributing! This document explains how to set
up a development environment, run the tests, and submit a change.

## Code of conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By
participating you agree to its terms.

## Reporting bugs

Open an issue on GitHub and use the **Bug report** template. Include:

- The exact command you ran.
- The provider and model you used (or were auto-detected).
- The full output, including any error messages.
- Your `bash --version` and `git --version`.

## Suggesting features

Open an issue using the **Feature request** template. Describe the
use-case, not just the solution. Adding a new LLM provider is usually a
5-line change in `lib/llm.sh` — open a PR directly if it's a standard
provider.

## Development setup

```bash
git clone https://github.com/alexk136/git-ai-commit.git
cd git-ai-commit

# Lint
shellcheck -x bin/git-ai-commit lib/*.sh

# Tests
bats tests/bats/
```

If you don't have `bats` or `shellcheck` installed:

```bash
# macOS
brew install bats-core shellcheck

# Debian / Ubuntu
sudo apt install shellcheck
git clone --depth 1 https://github.com/bats-core/bats-core.git
cd bats-core && ./install.sh ~/.local && cd ..

# Arch / Manjaro
sudo pacman -S shellcheck
git clone --depth 1 https://github.com/bats-core/bats-core.git
cd bats-core && ./install.sh ~/.local && cd ..
```

## Coding style

- **Shell**: `bash --noprofile --norc -n file.sh` must pass.
  `shellcheck -x` must produce zero warnings (we ignore `SC2034`
  for `CLI_*` sentinels used by indirection).
- **Indentation**: 4 spaces, no tabs.
- **Line length**: aim for 100 columns, hard limit 120.
- **Functions**: lowercase with underscores (`build_prompt`).
- **Global state**: use `GAIC_` prefix to avoid collisions.
- **Config keys**: uppercase (`PROVIDER`, `MODEL`).
- **Quote everything**: `"$var"`, never bare `$var`.
- **No `set -e` in lib/**: the entry point (`bin/git-ai-commit`) sets
  it, libraries should not. Return non-zero instead.

## Project layout

- `bin/git-ai-commit` — entry point, argument parsing, orchestration.
- `lib/ui.sh` — colored output, error helpers.
- `lib/config.sh` — config file + env var resolution.
- `lib/llm.sh` — provider abstraction, HTTP calls.
- `lib/tags.sh` — semver tag math.
- `lib/git.sh` — git plumbing helpers.
- `lib/prompt.sh` — prompt building + response cleanup.
- `tests/bats/` — bats test suite.

## Adding a new provider

1. Add a case to `get_provider_default_model` in `lib/llm.sh`.
2. Add a case to `get_provider_default_base_url`.
3. Add a case to `get_provider_env_key` and `get_provider_env_model`.
4. If the API is OpenAI-compatible, add it to the `case` in
   `generate_commit_message` — no new request function needed.
5. If the API is bespoke, write a `<name>_request` function and add a
   case in `generate_commit_message`.
6. Update the provider table in `README.md`.
7. Add the env vars to `.env.example`.
8. Add a `bats` integration test under `tests/bats/`.

## Submitting a pull request

1. Fork and create a topic branch (`git checkout -b fix/typo`).
2. Make your change. Include a test if it affects behavior.
3. Run `shellcheck -x bin/git-ai-commit lib/*.sh` and `bats tests/bats/`.
4. Commit with a clear message. The tool itself can write the message:
   `git-commit`.
5. Open a PR. Fill in the template. Reference any related issue.
6. Respond to review feedback. Squash fixups before merge.

## Release process

Releases are tagged manually. The version in `CHANGELOG.md` is updated,
a `vX.Y.Z` tag is pushed, and GitHub release notes are generated from the
changelog.

## License

By contributing you agree that your contributions will be licensed under
the [MIT License](LICENSE).
