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
- **Bot identity:** n/a  <!-- personal-collaborator auth, like discord_bot; not on the bot push path -->
- **Bot push script:** n/a
- **Token generator:** n/a
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
