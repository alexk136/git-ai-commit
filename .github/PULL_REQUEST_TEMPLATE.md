## Summary

<!-- One paragraph: what does this PR do and why? -->

## Type of change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would change existing behavior)
- [ ] Documentation update

## How was this tested?

<!-- Describe the tests you ran. If you added new bats tests, list them. -->

- [ ] `shellcheck -x bin/git-ai-commit lib/*.sh tests/bats/helpers/*.bash` is clean
- [ ] `bats tests/bats/` passes locally
- [ ] Manual smoke test with `<provider>` (or `ollama` if N/A)

## Checklist

- [ ] I have read [CONTRIBUTING.md](../CONTRIBUTING.md)
- [ ] I have updated [CHANGELOG.md](../CHANGELOG.md) under "Unreleased"
- [ ] I have updated [README.md](../README.md) if user-facing behavior changed
- [ ] My change follows the coding style (4-space indent, lowercase_with_underscores)
- [ ] I have added a `bats` test for new behavior

## Screenshots / logs

<!-- If relevant, paste terminal output to show the change works. -->
