# worldwidereh: static site (index.html, no build tooling) plus the Gradle Discord bot in BOT_DIR.
BOT_DIR := rehplacer-discord-bot/RehplacerBot

.DEFAULT_GOAL := help

# Per-checkout identity. Precedence: defaults < .worktree.env < environment < make VAR=...
# (no -include of .worktree.env: an included assignment would beat the environment).
wtenv = $(shell sed -n 's/^$(1)=//p' .worktree.env 2>/dev/null | tail -n 1)

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

.PHONY: help lint test build up down worktree-ports scripts-test scripts-lint

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

scripts-test: ## Run scripts/ unit tests
	bash scripts/worktree.test.sh

scripts-lint: ## shellcheck scripts/ (skips if shellcheck is absent)
	@if command -v shellcheck >/dev/null 2>&1; then shellcheck -x -P SCRIPTDIR scripts/*.sh; else echo "shellcheck: skipped (not installed)"; fi
