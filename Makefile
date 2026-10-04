# worldwidereh: static site (index.html, no build tooling) plus the Gradle Discord bot in BOT_DIR.
BOT_DIR := rehplacer-discord-bot/RehplacerBot

.DEFAULT_GOAL := help

.PHONY: help lint test

help: ## List the available targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-8s %s\n", $$1, $$2}'

lint: ## Compile and run Gradle verification tasks without tests (./gradlew check -x test)
	cd $(BOT_DIR) && ./gradlew check -x test

test: ## Build the Discord bot and run its tests (./gradlew build)
	cd $(BOT_DIR) && ./gradlew build
