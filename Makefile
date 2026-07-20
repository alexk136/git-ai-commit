SHELL       := /usr/bin/env bash
BIN         := bin/git-ai-commit
LIB         := $(wildcard lib/*.sh)
TESTS       := $(wildcard tests/bats/*.bats)
PREFIX      ?= /usr/local
BINDIR      ?= $(PREFIX)/bin

.PHONY: help install uninstall test lint smoke clean

help:
	@echo "Targets:"
	@echo "  install    Symlink $(BIN) to $(BINDIR)/git-commit"
	@echo "  uninstall  Remove the symlink"
	@echo "  test       Run bats test suite"
	@echo "  lint       Run shellcheck"
	@echo "  smoke      Quick smoke test (--help + --tag --dry-run)"
	@echo "  clean      Remove generated files"

install:
	@install -d $(BINDIR)
	@ln -sf $$(pwd)/$(BIN) $(BINDIR)/git-commit
	@echo "Installed: $(BINDIR)/git-commit → $$(pwd)/$(BIN)"

uninstall:
	@rm -f $(BINDIR)/git-commit
	@echo "Removed $(BINDIR)/git-commit"

test:
	@bats tests/bats/

lint:
	@shellcheck -x $(BIN) $(LIB) tests/bats/helpers/*.bash

smoke:
	@$(BIN) --help > /dev/null
	@tmp=$$(mktemp -d) && cd $$tmp && \
	  git init -q -b main && \
	  git config user.email test@example.com && \
	  git config user.name  Test && \
	  echo a > a && git add a && git commit -qm c && \
	  $(CURDIR)/$(BIN) --tag patch --dry-run
	@rm -rf $$tmp

clean:
	@find . -name '__pycache__' -prune -exec rm -rf {} +
	@find . -name '*.pyc' -delete
	@rm -rf .pytest_cache .ruff_cache htmlcov .coverage
