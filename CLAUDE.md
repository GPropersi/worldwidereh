# CLAUDE.md

Guidance for Claude Code when working in this repository. `worldwidereh` is a static site (a single
`index.html`) plus `rehplacer-discord-bot/RehplacerBot/` — a Java/Gradle Discord bot (`build.gradle`,
`gradlew`, containerized via its own `Dockerfile`/`docker-compose.yml`). There is no build tooling for
the static site itself.

## Claude Config

<!-- Consumed by the stronghold's central generic skills (see ~/code/CLAUDE.md).
     Stable keys — do not rename. Most keys are n/a: this is a static page plus a self-contained
     Gradle bot subproject. Account-specific IDs are never inlined here (secrets policy). -->

- **Repo slug:** `GPropersi/worldwidereh`
- **Default branch:** `main`
- **Plans store (central):** `~/code/plans/worldwidereh/{open,completed,research}/<topic>/` (no in-repo `plans/` directory; see `~/code/CLAUDE.md` "Central Plans Store")
- **Plans bucket:** `worldwidereh`
- **Bot identity:** `gpropersi-claude[bot]` `141576524+gpropersi-claude[bot]@users.noreply.github.com`  <!-- shared consolidated bot; installed on this repo -->
- **Bot push script:** `~/code/.claude/scripts/gh-app-push.sh` (central, repo-agnostic; derives the repo from `origin`, pushes as the shared bot)
- **Token generator:** `~/code/.claude/scripts/generate-gh-token.sh` (tracked in the stronghold — the shared consolidated `gpropersi-claude` App; one generator serves every repo, auto-resolves the installation from the repo's owner. Only the private key `~/.claude/u4i-app.pem` lives outside git)
- **Container runtime:** n/a for the static site; the `rehplacer-discord-bot/RehplacerBot/` subproject has its own `docker-compose.yml` (`docker compose up --build` within that dir)
- **App URL (Playwright MCP):** n/a (static `index.html` — open the file directly or serve with any static server)
- **Test login:** n/a
- **Commands:**
  | Purpose | Command |
  |---|---|
  | Static site build | n/a (plain `index.html`) |
  | Discord bot build/test | `make test` (wraps `./gradlew build` in `rehplacer-discord-bot/RehplacerBot/`) |
  | Lint / format | `make lint` (wraps `./gradlew check -x test`; no formatter) |
- **GitHub project board:** n/a
- **Issue labels:** resolve at runtime via `gh label list --repo GPropersi/worldwidereh` (do not invent labels)
- **PR reviewer:** `GPropersi`
- **Push gate:** (suites a push must pass; first matching row wins per changed path, all matched suites run sequentially)
  | Paths (space-separated globs) | Command |
  | --- | --- |
  | `**/*.md LICENSE .gitignore .gitattributes .claude/**` | na docs and repo metadata only, no code or build input |
  | `index.html` | na static page with no build tooling or tests |
  | `CLAUDE.md` | na agent guidance only, no code or build input |
  | `Makefile rehplacer-discord-bot/**` | `make test` |
