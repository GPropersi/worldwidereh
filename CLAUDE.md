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
- **Bot identity:** `gpropersi-claude[bot]` `141576524+gpropersi-claude[bot]@users.noreply.github.com`
- **Bot push script:** `~/code/.claude/scripts/gh-app-push.sh`
- **Token generator:** `~/code/.claude/scripts/generate-gh-token.sh`
- **Container runtime:** n/a for the static site; the `rehplacer-discord-bot/RehplacerBot/` subproject has its own `docker-compose.yml` (`docker compose up --build` within that dir). The root Makefile drives it as `docker compose -p $(COMPOSE_PROJECT_NAME) --project-directory ... -f ...`, with per-checkout values (`COMPOSE_PROJECT_NAME`, `BOT_PORT`, `BOT_CONTAINER`, `BOT_IMAGE`) read from the gitignored `.worktree.env`; `make up` is guarded (singleton-runtime): start it via `~/code/.claude/scripts/wt-singleton.sh run <checkout> up`
- **App URL (Playwright MCP):** n/a (static `index.html` — open the file directly or serve with any static server)
- **Test login:** n/a
- **Commands:**
  | Purpose | Command |
  |---|---|
  | Static site build | n/a (plain `index.html`) |
  | Discord bot build/test | `make test` (runs `./gradlew build` in `rehplacer-discord-bot/RehplacerBot/` inside a JDK 21 container, `eclipse-temurin:21-jdk-jammy`) |
  | Lint / format | `make lint` (runs `./gradlew check -x test` in the same JDK 21 container; no formatter) |
  | Bot image build | `make build` (docker compose build; never starts the bot) |
  | Start bot (guarded) | `make up` (denied bare by the singleton-runtime hook; use `wt-singleton.sh run <checkout> up`) |
  | Stop bot | `make down` |
  | Script tests | `make scripts-test` |
  | Script lint | `make scripts-lint` (shellcheck; skipped when absent) |
  | Create worktree | `make worktree-new name=<slug> [b=<branch>] [base=<ref>]` |
  | Remove worktree | `make worktree-rm` (run inside the worktree) |
  | Resolved port/project | `make worktree-ports` |
  | List targets | `make help` |

  Worktrees (ports, isolation, the singleton `make up` restriction, removal): see `docs/worktrees.md`.
- **Push gate:** (suites a push must pass; first matching row wins per changed path, all matched suites run sequentially)
  | Paths (space-separated globs)                  | Command                 |
  | ----------------------------------------------- | ----------------------- |
  | `rehplacer-discord-bot/**`                      | `make test`             |
  | `scripts/** Makefile`                           | `make scripts-test`     |
  | `docs/** *.md .claude/** .gitignore`            | na docs and config only |
- **GitHub project board:** n/a
- **Issue labels:** resolve at runtime via `gh label list --repo GPropersi/worldwidereh` (do not invent labels)
- **PR reviewer:** `GPropersi`
- **Worktree policy:** `singleton-runtime`
- **Worktree guarded targets:** `up`
- **Worktree link:** `rehplacer-discord-bot/RehplacerBot/.env`
- **Worktree ports:** `BOT_PORT=9980`
- **Worktree setup:** `n/a`
- **Worktree teardown:** `n/a`
- **Worktree allowed targets:** `n/a`
