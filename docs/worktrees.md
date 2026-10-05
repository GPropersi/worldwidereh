# Worktrees

worldwidereh can be built in parallel git worktrees, but only one copy of the Discord bot may run at a time, because there is a single `DISCORD_TOKEN`. This page covers creating and removing worktrees, how each one is isolated, and the singleton restriction on starting the bot. Creating and removing worktrees works standalone, with only this repo's Makefile and `scripts/worktree.sh`; the singleton guard needs a Claude Code session with the stronghold.

## Primary clone first

The primary clone holds the real, untracked `rehplacer-discord-bot/RehplacerBot/.env` (`DISCORD_TOKEN`, `CF_CLIENT_ID`, `CF_CLIENT_SECRET`). `make worktree-new` symlinks that file into each new worktree at the same relative path.

- If the primary has no `.env` but has `.env.example`, the worktree gets a copy of `.env.example` (a regular file) and a warning; fill in real values before starting the bot.
- If neither exists, you get a warning and the worktree has no secrets.
- A real file already at that path is never overwritten.
- The worktree `.env` is a symlink to the primary's file, so editing it edits the shared secret for every checkout. The `.env.example` copy is a plain file and is never synced with later changes to the primary's files.
- Never commit `.env`. It is ignored by `RehplacerBot/.gitignore` and `deploy.sh` ships it to the Pi.
- Per-worktree values (`BOT_PORT`, `BOT_CONTAINER`, ...) never belong in `.env`: it is copied to the Pi. They live in the gitignored `.worktree.env`.

## Create

```
make worktree-new name=<slug> [b=<branch>] [base=<ref>]
```

Run it from the primary clone or any linked worktree. The worktree lands in `<primary>/.claude/worktrees/<slug>`.

- **Base:** the default base is `origin/<Default branch>` (from `origin/HEAD`, falling back to `main`). `base=<ref>` cuts a brand-new branch from an unmerged ref. When the branch already exists locally it is attached as is, and when it exists only on origin it is checked out tracking `origin/<branch>`; in both cases a given `base=` is ignored with a warning. A missing base errors with a `git fetch origin` / `base=` hint.
- **Naming:** `name` is normalized to the slug (lowercase, anything outside `[a-z0-9-]` becomes `-`, leading `-` stripped, cut to 40 characters, trailing `-` stripped); it is never used raw. With only `b=<branch>`, the slug is derived from the branch (`infra/worktree-adoption` gives `infra-worktree-adoption`). With only `name`, the branch defaults to the slug. When both are given they must normalize to the same slug, otherwise `new` refuses and names both slugs. `$` and `#` in `name=` or `b=` are unsupported through make (only `'` is escaped); for an unusual branch name call the script directly: `WT_BRANCH='...' bash scripts/worktree.sh new`.
- **Uniqueness:** the slug is the directory basename. It may not be `worldwidereh` or the primary's directory name, may not match an existing `.claude/worktrees/<slug>`, and `worldwidereh-<slug>` may not already be a compose project (checked with `docker compose ls -a`; if Docker is unavailable the check is skipped with a warning).
- **What runs afterwards:** `make -C <worktree> build` only (a `docker compose build`). It never starts the bot. Set `WT_SKIP_BUILD=1` to skip it: `WT_SKIP_BUILD=1 bash scripts/worktree.sh new` (with `WT_NAME`/`WT_BRANCH`/`WT_BASE` set as needed).
- **Pre-created bind dirs:** `logs/` and `commands/` under `rehplacer-discord-bot/RehplacerBot/` are created as your user, so Docker does not create them root-owned (which would block a later non-force `git worktree remove`). `commands/` is gitignored (anchored `/commands/`).
- **Failure recovery:** a failure after `git worktree add` (linking `.env`, allocating a slot, writing `.worktree.env`) leaves the worktree in place and prints the exact discard command `git -C <primary> worktree remove <path>` (plus `git branch -D <branch>` if the branch was newly created and is unwanted). A failed build prints `make -C <path> worktree-rm` to discard and `make -C <path> build` to retry. Nothing is deleted automatically. The slot lock (`<git-common-dir>/worldwidereh-worktree-slot.lock`) is reclaimed automatically when its pid is dead, or when it is pid-less and older than 5 s. A `slot lock held by pid N` error means another run is live: check that pid first, and remove the lock directory only if you are sure no run is active.

## Ports and `.worktree.env`

The primary clone uses slot 0, port `9980`. A worktree gets slot `s` in 1..99 and port `9980 + s`.

- The start slot is `(cksum("worldwidereh:" + slug) % 99) + 1`; allocation walks forward through the 99 slots.
- A slot is skipped if a sibling `.claude/worktrees/*/.worktree.env` already claims it (`BOT_SLOT=`) or its port is busy. The busy probe asks Docker (`docker ps --filter publish=<port>`) and then tries an IPv4 loopback connect to `127.0.0.1:<port>`. Anything the probe cannot see (an IPv6-only listener, a process that binds later) is caught at start time by compose's "port is already allocated" error.
- Allocation happens under a lock directory in the git common dir (`worldwidereh-worktree-slot.lock`), so concurrent `worktree-new` runs cannot pick the same slot. Ambient `BOT_PORT` and `COMPOSE_PROJECT_NAME` in your shell are ignored by the allocator.
- `.worktree.env` is plain `KEY=VALUE` (mode 0600, gitignored, also listed in the git common dir's `info/exclude`): `SLUG`, `PRIMARY_ROOT`, `IS_PRIMARY=0`, `BOT_SLOT`, `COMPOSE_PROJECT_NAME`, `BOT_PORT`, `BOT_CONTAINER`, `BOT_IMAGE`. It is read, never sourced.
- **Precedence** for the four variables the Makefile uses: defaults < `.worktree.env` < environment < `make VAR=...`. Defaults are project `worldwidereh`, port `9980`, and empty container/image (compose then uses its own defaults).
- `make worktree-ports` prints the resolved `BOT_PORT` and `COMPOSE_PROJECT_NAME` for the current checkout.

## What each worktree isolates

| Resource        | Primary clone          | Worktree `<slug>`           |
|-----------------|------------------------|-----------------------------|
| Compose project | `worldwidereh`         | `worldwidereh-<slug>`       |
| Container name  | `rehplacer-bot`        | `worldwidereh-<slug>-bot`   |
| Image tag       | `rehplacer-bot:latest` | `worldwidereh-<slug>:local` |
| Host port       | `9980`                 | `9980 + slot`               |

`make build` and `make up` in a worktree never retag the shared `rehplacer-bot:latest` (`deploy.sh` does; see the Pi deploy path). The compose file declares no named volumes, so no volume is shared.

What a worktree cannot isolate: the Discord application. All checkouts share one `DISCORD_TOKEN`, one bot identity and its global slash commands, so two running copies would fight over the same gateway session and command registrations. That is why the bot is a singleton (next section).

## Singleton-runtime restriction

The repo declares `Worktree policy: singleton-runtime` with `Worktree guarded targets: up`.

- A bare `make up` is denied by the Claude Code hook in every checkout, including the primary. Start the bot through the wrapper instead:

  ```
  ~/code/.claude/scripts/wt-singleton.sh run <checkout> up
  ```

  `make up` runs `docker compose up -d --build`, detached, so the bot outlives the wrapper. Liveness is judged from the compose `working_dir` label under the checkout, so the stack must run with its project directory inside the checkout (the Makefile does this).
- `~/code/.claude/scripts/wt-singleton.sh status worldwidereh` shows the current holder. A second `run` while one is live is refused and names the holder. `wt-singleton.sh release --force` needs the user's approval.
- `make down` and `make worktree-rm` are unguarded. Stop the running copy with `make down` in the checkout that holds it before starting another.
- Starting the stack needs the Docker `journald` logging driver (the compose file sets `logging.driver: journald`), so the host needs `/run/systemd/journal/socket`. `build`, `lint` and `test` do not need it.
- **What bypasses the hook:** a nested `$(MAKE) up`, a raw `docker compose up`, a direct `docker run` or `docker start` of a built image, and `deploy.sh` are invisible to it. Never use them in any checkout while another copy may be live.
- **Without a Claude Code session:** the hook and wrapper exist only in a Claude Code session on a machine with the stronghold. Elsewhere nothing stops a second `make up`, so make sure only one copy runs per `DISCORD_TOKEN`: run `make down` in the other checkout first.
- `make build`, `make lint` and `make test` are safe in any number of worktrees. `lint` and `test` run Gradle inside an `eclipse-temurin:21-jdk-jammy` container, because the host JDK is newer than the Gradle 8.5 wrapper supports.

## Remove

Run inside the worktree:

```
make worktree-rm
```

- The compose project is read only from the worktree's own `.worktree.env` and must equal `worldwidereh-<worktree directory basename>`. If the file is missing or the value differs (for example the primary's `worldwidereh`), the Docker step is skipped with a warning and Docker is never run against another project.
- `docker compose down` must succeed. If it fails (including Docker not running), `rm` aborts, leaves the worktree in place, and prints the manual fallback: start Docker and rerun `make worktree-rm`, or, after confirming no container of that project is running, `git -C <primary> worktree remove <path>`. When `.worktree.env` is valid, a failed down aborts, so the directory is not deleted under a live bot. When the Docker step is skipped with the warning, check `docker ps` for a leftover container of that project before continuing.
- The image is removed only when `BOT_IMAGE` in the file is exactly `worldwidereh-<slug>:local`; a removal failure only warns, and `rehplacer-bot:latest` is never touched.
- Then a non-force `git worktree remove` runs; git's error is shown as is (for example root-owned files in `logs/`). The branch is kept. Your shell stays in the removed directory until you `cd` out.
- To discard the branch too, from the primary: `git branch -D <branch>`.

## Pi deploy path

`deploy.sh` and the Raspberry Pi keep the default names and port, byte for byte: image `rehplacer-bot:latest`, container `rehplacer-bot`, host port `9980`, and the `journald` tag `discord-bot-rehplacer`. The compose file only parameterizes them with defaults (`${BOT_IMAGE:-rehplacer-bot:latest}`, `${BOT_CONTAINER:-rehplacer-bot}`, `${BOT_PORT:-9980}`). The Pi does not use the Makefile. Keep per-worktree values out of `.env`, since `deploy.sh` copies it to the Pi. A worktree's `.env` may be a placeholder copy of `.env.example`, and `deploy.sh` scps `.env` to the Pi and builds and tags the shared `rehplacer-bot:latest`, so running it from a worktree could overwrite the Pi's real `.env` with placeholders and retag the shared image.

Bare `docker compose` in `RehplacerBot/` uses the project name `rehplacerbot`, which the make targets do not manage. If an old local stack from before the rename exists, run `docker compose -p rehplacerbot down` once so `make up` does not collide on the container name and port 9980.

## Via the stronghold

From `~/code`, `make wt-new REPO=worldwidereh BRANCH=<branch>` and `make wt-rm REPO=worldwidereh BRANCH=<branch>` delegate to this repo's `worktree-new` and `worktree-rm` targets, so the behavior above applies. `INIT=1` bootstraps a plain worktree (its generated `.worktree.env` carries only `COMPOSE_PROJECT_NAME`, so the port stays `9980`) for a branch whose repo has no owned targets yet; prefer the owned targets afterwards.

## Residual risk

The policy does not stop `deploy.sh`, which restarts the production bot on the Pi with the same token. Do not run it while a local copy of the bot is live, and never run it from a worktree (see the Pi deploy path for why).
