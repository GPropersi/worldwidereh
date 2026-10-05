# worldwidereh: static site (index.html, no build tooling) plus the Gradle Discord bot in BOT_DIR.
BOT_DIR := rehplacer-discord-bot/RehplacerBot

.DEFAULT_GOAL := help

# Per-checkout identity. Precedence: defaults < .worktree.env < environment < make VAR=...
# (no -include of .worktree.env: an included assignment would beat the environment).
# Only values matching [A-Za-z0-9][A-Za-z0-9._:-]* are accepted (no leading dash, so never option-like); a tampered line is ignored (default applies),
# so unvalidated file content never reaches a recipe line.
wtenv = $(shell sed -n 's/^$(1)=\([A-Za-z0-9][A-Za-z0-9._:-]*\)$$/\1/p' .worktree.env 2>/dev/null | tail -n 1)

ifndef COMPOSE_PROJECT_NAME
COMPOSE_PROJECT_NAME := $(or $(call wtenv,COMPOSE_PROJECT_NAME),worldwidereh)
endif
ifndef BOT_PORT
BOT_PORT := $(or $(call wtenv,BOT_PORT),9980)
endif
ifndef BOT_CONTAINER
BOT_CONTAINER := $(or $(call wtenv,BOT_CONTAINER),)
endif
ifndef BOT_IMAGE
BOT_IMAGE := $(or $(call wtenv,BOT_IMAGE),)
endif
export COMPOSE_PROJECT_NAME BOT_PORT BOT_CONTAINER BOT_IMAGE

COMPOSE := docker compose -p $(COMPOSE_PROJECT_NAME) --project-directory $(BOT_DIR) -f $(BOT_DIR)/docker-compose.yml

# Gradle runs in the same JDK 21 image the Dockerfile builds on (the host JDK is newer than the wrapper supports).
GRADLE_RUN = docker run --rm --user $$(id -u):$$(id -g) -e HOME=/tmp -e GRADLE_USER_HOME=/tmp/gradle -v $(CURDIR)/$(BOT_DIR):/app -w /app eclipse-temurin:21-jdk-jammy ./gradlew --no-daemon

.PHONY: help lint test build up down worktree-ports worktree-new worktree-rm scripts-test scripts-lint

help: ## List the available targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-14s %s\n", $$1, $$2}'

lint: ## Compile and run Gradle verification tasks without tests in a JDK 21 container (gradlew check -x test)
	$(GRADLE_RUN) check -x test

test: ## Build the Discord bot and run its tests in a JDK 21 container (gradlew build)
	$(GRADLE_RUN) build

build: ## Build the bot image (docker compose build; JDK 21 in the container)
	$(COMPOSE) build

up: ## Start the live bot detached (guarded: use wt-singleton.sh run <checkout> up)
	$(COMPOSE) up -d --build

down: ## Stop the bot stack
	$(COMPOSE) down

worktree-ports: ## Print this checkout's resolved BOT_PORT and project
	@echo BOT_PORT=$(BOT_PORT)
	@echo COMPOSE_PROJECT_NAME=$(COMPOSE_PROJECT_NAME)

# worktree-new must not hand the primary's defaults to the slot allocator (the script also ignores them).
worktree-new: unexport BOT_PORT := $(BOT_PORT)
worktree-new: unexport COMPOSE_PROJECT_NAME := $(COMPOSE_PROJECT_NAME)
worktree-new: unexport BOT_CONTAINER := $(BOT_CONTAINER)
worktree-new: unexport BOT_IMAGE := $(BOT_IMAGE)
worktree-new: ## Create a worktree: make worktree-new name=<slug> [b=<branch>] [base=<ref>]
	@WT_NAME='$(subst ','\'',$(name))' WT_BRANCH='$(subst ','\'',$(b))' WT_BASE='$(subst ','\'',$(base))' bash scripts/worktree.sh new

worktree-rm: ## Remove this worktree (run inside it)
	@bash scripts/worktree.sh rm

scripts-test: ## Run scripts/ unit tests
	bash scripts/worktree.test.sh

scripts-lint: ## shellcheck scripts/ (skips if shellcheck is absent)
	@if command -v shellcheck >/dev/null 2>&1; then shellcheck -x -P SCRIPTDIR scripts/*.sh; else echo "shellcheck: skipped (not installed)"; fi
