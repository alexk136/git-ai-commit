# Security Policy

## Supported versions

| Version | Supported          |
| ------- | ------------------ |
| 0.3.x   | :white_check_mark: |
| < 0.3   | :x:                |

## Reporting a vulnerability

**Please do not file a public issue for security problems.**

Email `security@alexk136.dev` (or open a private security advisory on
GitHub via the **Security** tab → **Advisories** → **New draft security
advisory**). Include:

- Description of the vulnerability and impact.
- Reproduction steps.
- Affected version(s).

We aim to acknowledge new reports within 72 hours and ship a fix within
14 days for critical issues, 30 days for everything else.

## Threat model

`git-commit` is a local CLI that:

- Reads your staged/unstaged git diff.
- Sends it to a remote LLM provider (if not using local Ollama).
- Runs `git commit` and `git push` on your behalf.

The most relevant risks are:

- **API key leakage** — keys may end up in shell history. The tool
  reads keys from env vars, never from command line, but you should
  still use a secret manager or `direnv` to scope them.
- **Prompt injection** — if your diff contains attacker-controlled
  text (e.g. a copied error message), it may influence the LLM's
  response. The tool mitigates this by cleaning common AI prefixes
  but cannot prevent every case.
- **Tag overwrites** — `--tag major` will create `v2.0.0` even if you
  already have one. Review with `--dry-run` first when bumping major
  versions in shared repos.

## What we will NOT fix

- Bugs in upstream LLM providers.
- Issues caused by running with elevated privileges (e.g. `sudo
  git-commit`) — the tool does not require root for normal use.
- Rate limiting or quota issues from your provider.

## Past advisories

None.
