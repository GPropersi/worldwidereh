#!/usr/bin/env bash
# worktree.sh - per-checkout identity for parallel worldwidereh worktrees.
#
# Plain-bash port of the 4irl-notifs/tasktracker worktree.mjs + ports.mjs (this repo has no
# Node). bash 3.2-safe; git is always called with argument lists; .worktree.env files are
# parsed with sed and never sourced or eval'd.
#
# Sourced by scripts/worktree.test.sh; executed directly it dispatches subcommands (see
# wt_main). Everything is rooted at the PRIMARY checkout (dirname of the git common dir),
# never --show-toplevel, so it works from the primary or any linked worktree.
#
# Test seams (all optional env): WT_BUSY_PORTS (space-separated busy ports, replaces the real
# probe), WT_LOCK_NOW (epoch seconds used for lock age), WT_NO_JQ (force the grep parse of
# `docker compose ls`), WT_SKIP_BUILD (skip the post-create build).
set -euo pipefail

WT_PROJECT_PREFIX="worldwidereh"
WT_BASE_PORT=9980
WT_SLOTS=99
WT_BOT_REL="rehplacer-discord-bot/RehplacerBot"
WT_LOCK_HELD=0
WT_LOCK_DIR=""

wt_err() { printf 'worktree: error: %s\n' "$*" >&2; }
wt_warn() { printf 'worktree: warning: %s\n' "$*" >&2; }

# wt_slug <raw>: lowercase, [^a-z0-9-] -> '-', strip leading '-', cut 40, strip trailing '-'.
wt_slug() {
  local raw="${1-}" s
  s="$(printf '%s' "$raw" | LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C tr -c 'a-z0-9-' '-')"
  while [ "${s#-}" != "$s" ]; do s="${s#-}"; done
  s="${s:0:40}"
  while [ "${s%-}" != "$s" ]; do s="${s%-}"; done
  if [ -z "$s" ]; then
    wt_err "cannot derive a slug from '$raw'"
    return 1
  fi
  printf '%s\n' "$s"
}

# wt_parse_args: reads WT_NAME / WT_BRANCH / WT_BASE (empty = unset); sets W_SLUG, W_BRANCH, W_BASE.
# The slug is always wt_slug(name or branch); the branch defaults to the slug.
wt_parse_args() {
  local name="${WT_NAME-}" branch="${WT_BRANCH-}"
  if [ -z "$name" ] && [ -z "$branch" ]; then
    wt_err "a name or a branch is required"
    return 1
  fi
  if [ -n "$name" ]; then
    W_SLUG="$(wt_slug "$name")" || return 1
  else
    W_SLUG="$(wt_slug "$branch")" || return 1
  fi
  W_BRANCH="${branch:-$W_SLUG}"
  W_BASE="${WT_BASE-}"
}

# The git common dir (absolute, symlinks resolved) and the primary checkout derived from it.
wt_common_dir() {
  local d
  d="$(git rev-parse --path-format=absolute --git-common-dir)" || return 1
  (cd -P "$d" && pwd -P)
}
wt_primary_root() {
  local c
  c="$(wt_common_dir)" || return 1
  dirname "$c"
}

# wt_default_branch: origin's default branch, falling back to main.
wt_default_branch() {
  local ref
  ref="$(git symbolic-ref --short refs/remotes/origin/HEAD 2> /dev/null)" || ref=""
  ref="${ref#origin/}"
  printf '%s\n' "${ref:-main}"
}

# wt_project_exists <project>: 0 when `docker compose ls -a` lists it. When docker is
# unavailable it warns and reports absent (the check is skipped, never fatal).
wt_project_exists() {
  local name="$1" json
  if ! json="$(docker compose ls -a --format json 2> /dev/null)"; then
    wt_warn "docker unavailable; skipping the compose project check"
    return 1
  fi
  if [ -z "${WT_NO_JQ-}" ] && command -v jq > /dev/null 2>&1; then
    printf '%s' "$json" | jq -e --arg n "$name" 'any(.[]; .Name == $n)' > /dev/null 2>&1
  else
    printf '%s' "$json" | grep -Eq "\"Name\": *\"$name\""
  fi
}

# wt_port_busy <port>: busy when listed in WT_BUSY_PORTS (when that is set it is the only
# source), else when docker publishes it, else when something accepts on IPv4 loopback.
wt_port_busy() {
  local port="$1" w ids
  if [ -n "${WT_BUSY_PORTS+x}" ]; then
    for w in $WT_BUSY_PORTS; do
      if [ "$w" = "$port" ]; then return 0; fi
    done
    return 1
  fi
  if ids="$(docker ps --filter "publish=$port" -q 2> /dev/null)"; then
    if [ -n "$ids" ]; then return 0; fi
  fi
  (exec 3<> "/dev/tcp/127.0.0.1/$port") 2> /dev/null
}

# claimed_slots <primary>: BOT_SLOT of every sibling worktree (sed, never sourced), one per line.
claimed_slots() {
  local primary="$1" f v
  for f in "$primary"/.claude/worktrees/*/.worktree.env; do
    if [ ! -f "$f" ]; then continue; fi
    v="$(sed -n 's/^BOT_SLOT=//p' "$f" | tail -n 1)"
    case "$v" in
      '' | *[!0-9]*) continue ;;
    esac
    printf '%s\n' "$((10#$v))"
  done
}

# alloc_slot <slug>: prints "<slot> <port>". Slot 0 is the primary (9980); worktrees get slots
# 1..99 (9980 + slot), starting at (cksum("worldwidereh:<slug>") % 99) + 1 and walking with
# wraparound. Ambient BOT_PORT / COMPOSE_PROJECT_NAME are never read.
alloc_slot() {
  local slug="$1" primary ck start i s port flat
  primary="$(wt_primary_root)" || return 1
  flat=" $(claimed_slots "$primary" | tr '\n' ' ')"
  ck="$(printf '%s' "$WT_PROJECT_PREFIX:$slug" | cksum | awk '{print $1}')"
  start=$((ck % WT_SLOTS + 1))
  for ((i = 0; i < WT_SLOTS; i++)); do
    s=$(((start - 1 + i) % WT_SLOTS + 1))
    port=$((WT_BASE_PORT + s))
    case "$flat" in
      *" $s "*) continue ;;
    esac
    if wt_port_busy "$port"; then continue; fi
    printf '%s %s\n' "$s" "$port"
    return 0
  done
  wt_err "no free port slot: all $WT_SLOTS slots (ports $((WT_BASE_PORT + 1))-$((WT_BASE_PORT + WT_SLOTS))) are claimed or busy"
  return 1
}

# plan_new: validate WT_NAME / WT_BRANCH / WT_BASE and print the plan. Sets W_PRIMARY, W_SLUG,
# W_BRANCH, W_BASE, W_MODE (local | origin | new) and W_PATH. Returns non-zero on any refusal.
plan_new() {
  local project
  wt_parse_args || return 1
  W_PRIMARY="$(wt_primary_root)" || return 1
  printf 'slug: %s\n' "$W_SLUG"

  if [ -n "${WT_NAME-}" ] && [ -n "${WT_BRANCH-}" ]; then
    local name_slug branch_slug
    name_slug="$(wt_slug "$WT_NAME")" || return 1
    branch_slug="$(wt_slug "$WT_BRANCH")" || return 1
    if [ "$name_slug" != "$branch_slug" ]; then
      wt_err "name slug '$name_slug' and branch slug '$branch_slug' differ; the directory must match the branch's slug"
      return 1
    fi
  fi
  if [ "$W_SLUG" = "$WT_PROJECT_PREFIX" ] || [ "$W_SLUG" = "$(basename "$W_PRIMARY")" ]; then
    wt_err "slug '$W_SLUG' is reserved (the primary checkout / project name)"
    return 1
  fi
  W_PATH="$W_PRIMARY/.claude/worktrees/$W_SLUG"
  if [ -e "$W_PATH" ]; then
    wt_err "$W_PATH already exists"
    return 1
  fi
  case "$W_BRANCH" in
    -*)
      wt_err "branch '$W_BRANCH' must not start with '-'"
      return 1
      ;;
  esac
  case "$W_BRANCH" in
    *'@{'*)
      wt_err "'$W_BRANCH' is not a valid branch name (contains '@{')"
      return 1
      ;;
  esac
  case "$W_BASE" in
    -*)
      wt_err "base '$W_BASE' must not start with '-'"
      return 1
      ;;
  esac
  if ! git check-ref-format --branch "$W_BRANCH" > /dev/null 2>&1; then
    wt_err "'$W_BRANCH' is not a valid branch name"
    return 1
  fi
  project="$WT_PROJECT_PREFIX-$W_SLUG"
  if wt_project_exists "$project"; then
    wt_err "compose project '$project' already exists; pick another name"
    return 1
  fi

  if git show-ref --verify --quiet "refs/heads/$W_BRANCH"; then
    W_MODE=local
  elif git show-ref --verify --quiet "refs/remotes/origin/$W_BRANCH"; then
    W_MODE=origin
  else
    W_MODE=new
  fi
  if [ "$W_MODE" = new ]; then
    if [ -z "$W_BASE" ]; then W_BASE="origin/$(wt_default_branch)"; fi
    if ! git rev-parse --verify --quiet "$W_BASE^{commit}" > /dev/null; then
      wt_err "base '$W_BASE' not found; run 'git fetch origin' or pass base=<ref>"
      return 1
    fi
  elif [ -n "$W_BASE" ]; then
    wt_warn "base '$W_BASE' ignored: branch '$W_BRANCH' already exists ($W_MODE)"
    W_BASE=""
  fi
  printf 'branch: %s (%s)\nbase: %s\npath: %s\n' "$W_BRANCH" "$W_MODE" "${W_BASE:--}" "$W_PATH"
}

# write_env <worktree> <slug> <slot> <port>: atomic (mktemp in the target dir, then mv), mode 0600.
write_env() {
  local wt="$1" slug="$2" slot="$3" port="$4" primary tmp
  primary="$(wt_primary_root)" || return 1
  tmp="$(mktemp "$wt/.worktree.env.XXXXXX")" || return 1
  chmod 600 "$tmp" || {
    rm -f "$tmp"
    return 1
  }
  if ! printf 'SLUG=%s\nPRIMARY_ROOT=%s\nIS_PRIMARY=0\nBOT_SLOT=%s\nCOMPOSE_PROJECT_NAME=%s\nBOT_PORT=%s\nBOT_CONTAINER=%s\nBOT_IMAGE=%s\n' \
    "$slug" "$primary" "$slot" "$WT_PROJECT_PREFIX-$slug" "$port" "$WT_PROJECT_PREFIX-$slug-bot" "$WT_PROJECT_PREFIX-$slug:local" > "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  if ! mv -f "$tmp" "$wt/.worktree.env"; then
    rm -f "$tmp"
    return 1
  fi
}

# ensure_excludes: add /.worktree.env to <git-common-dir>/info/exclude once.
ensure_excludes() {
  local common ex
  common="$(wt_common_dir)" || return 1
  ex="$common/info/exclude"
  mkdir -p "$common/info" || return 1
  if [ -f "$ex" ] && grep -qxF '/.worktree.env' "$ex"; then return 0; fi
  if [ -s "$ex" ] && [ -n "$(tail -c 1 "$ex")" ]; then printf '\n' >> "$ex" || return 1; fi
  printf '/.worktree.env\n' >> "$ex" || return 1
}

# link_env <primary> <worktree>: symlink the primary's .env, else copy .env.example (warn),
# else warn. An existing file or link is never touched.
link_env() {
  local primary="$1" wt="$2" rel="$WT_BOT_REL" src dest ex
  src="$primary/$rel/.env"
  dest="$wt/$rel/.env"
  ex="$primary/$rel/.env.example"
  if [ -e "$dest" ] || [ -L "$dest" ]; then return 0; fi
  mkdir -p "$wt/$rel" || return 1
  if [ -e "$src" ]; then
    ln -s "$src" "$dest" || return 1
    return 0
  fi
  if [ ! -f "$ex" ] && [ -f "$wt/$rel/.env.example" ]; then ex="$wt/$rel/.env.example"; fi
  if [ -f "$ex" ]; then
    cp "$ex" "$dest" || return 1
    chmod 600 "$dest" || return 1
    wt_warn "the primary has no $rel/.env; copied .env.example (fill in real values before starting the bot)"
  else
    wt_warn "neither $rel/.env nor .env.example found; the bot will have no secrets"
  fi
}

# ensure_bind_dirs <worktree>: compose bind-mounts ./logs and ./commands; create them as the
# invoking user so Docker never makes them root-owned.
ensure_bind_dirs() {
  local wt="$1"
  mkdir -p "$wt/$WT_BOT_REL/logs" "$wt/$WT_BOT_REL/commands" || return 1
}

wt_mtime() { stat -c %Y "$1" 2> /dev/null || stat -f %m "$1"; }

# acquire_lock / release_lock: mkdir lock in the git common dir with a pid file. A dead pid is
# reclaimed; a pid-less lock is reclaimed once older than 5 s (WT_LOCK_NOW is the time seam).
# Note: on success this installs an EXIT trap that REPLACES any EXIT trap the caller had set.
acquire_lock() {
  local common dir pid="" now mt age stale cur
  common="$(wt_common_dir)" || return 1
  dir="$common/worldwidereh-worktree-slot.lock"
  if ! mkdir "$dir" 2> /dev/null; then
    if [ -f "$dir/pid" ]; then pid="$(cat "$dir/pid" 2> /dev/null || true)"; fi
    if [ -n "$pid" ]; then
      if kill -0 "$pid" 2> /dev/null; then
        wt_err "slot lock held by pid $pid ($dir)"
        return 1
      fi
    else
      now="${WT_LOCK_NOW:-$(date +%s)}"
      if mt="$(wt_mtime "$dir")"; then
        age=$((now - mt))
        if [ "$age" -le 5 ]; then
          wt_err "slot lock held ($dir)"
          return 1
        fi
      else
        # The lock vanished between mkdir and stat: retry the mkdir once.
        if mkdir "$dir" 2> /dev/null; then
          printf '%s\n' "$$" > "$dir/pid"
          WT_LOCK_DIR="$dir"
          WT_LOCK_HELD=1
          trap release_lock EXIT
          return 0
        fi
        wt_err "slot lock held ($dir)"
        return 1
      fi
    fi
    # Atomic reclaim: whoever wins the mv owns the stale dir; the loser reports held.
    # WT_LOCK_PRE_MV (test seam): a command run between the stale judgement and the mv.
    if [ -n "${WT_LOCK_PRE_MV:-}" ]; then "$WT_LOCK_PRE_MV" "$dir"; fi
    stale="$dir.stale-$$"
    if ! mv "$dir" "$stale" 2> /dev/null; then
      wt_err "slot lock held ($dir)"
      return 1
    fi
    # Re-check: if the dir we moved now names a live pid other than the one we judged stale, a
    # concurrent acquirer replaced it before our mv. Put it back (best effort) and report held.
    cur=""
    if [ -f "$stale/pid" ]; then cur="$(cat "$stale/pid" 2> /dev/null || true)"; fi
    if [ -n "$cur" ] && [ "$cur" != "$pid" ] && kill -0 "$cur" 2> /dev/null; then
      if [ ! -e "$dir" ]; then mv "$stale" "$dir" 2> /dev/null || true; fi
      rm -rf "$stale"
      wt_err "slot lock held by pid $cur ($dir)"
      return 1
    fi
    rm -rf "$stale"
    if ! mkdir "$dir" 2> /dev/null; then
      wt_err "slot lock held ($dir)"
      return 1
    fi
  fi
  printf '%s\n' "$$" > "$dir/pid"
  WT_LOCK_DIR="$dir"
  WT_LOCK_HELD=1
  trap release_lock EXIT
}
release_lock() {
  if [ "$WT_LOCK_HELD" = 1 ] && [ -n "$WT_LOCK_DIR" ]; then
    if [ "$(cat "$WT_LOCK_DIR/pid" 2> /dev/null || true)" = "$$" ]; then
      rm -rf "$WT_LOCK_DIR"
    fi
    WT_LOCK_HELD=0
  fi
  return 0
}

# rm_project <worktree>: prints the compose project to tear down, read ONLY from
# <worktree>/.worktree.env and only when it equals worldwidereh-<dir basename>. Otherwise
# warns, prints nothing and returns non-zero (the caller must then skip docker).
rm_project() {
  local wt="$1" file val expected
  file="$wt/.worktree.env"
  if [ ! -f "$file" ]; then
    wt_warn "no .worktree.env in $wt; skipping the docker step"
    return 1
  fi
  val="$(sed -n 's/^COMPOSE_PROJECT_NAME=//p' "$file" | tail -n 1)" || true
  expected="$WT_PROJECT_PREFIX-$(basename "$wt")"
  if [ "$val" != "$expected" ]; then
    wt_warn "COMPOSE_PROJECT_NAME in $file is '${val:-<unset>}', expected '$expected'; skipping the docker step"
    return 1
  fi
  printf '%s\n' "$val"
}

# wt_finish_setup: everything after `git worktree add` that can fail (the caller prints the
# discard command on failure). Explicit returns: this runs inside an `if`, where errexit is off.
wt_finish_setup() {
  local sp
  link_env "$W_PRIMARY" "$W_PATH" || return 1
  ensure_bind_dirs "$W_PATH" || return 1
  sp="$(alloc_slot "$W_SLUG")" || return 1
  write_env "$W_PATH" "$W_SLUG" "${sp% *}" "${sp#* }" || return 1
}

# wt_new: create .claude/worktrees/<slug> with its own identity, then build (never `up`).
wt_new() {
  plan_new || return 1
  acquire_lock || return 1
  mkdir -p "$W_PRIMARY/.claude/worktrees" || return 1
  ensure_excludes || return 1
  case "$W_MODE" in
    local) git -C "$W_PRIMARY" worktree add "$W_PATH" "$W_BRANCH" ;;
    origin) git -C "$W_PRIMARY" worktree add --track -b "$W_BRANCH" "$W_PATH" "origin/$W_BRANCH" ;;
    *) git -C "$W_PRIMARY" worktree add --no-track -b "$W_BRANCH" "$W_PATH" "$W_BASE" ;;
  esac || return 1

  if ! wt_finish_setup; then
    wt_err "setup failed after the worktree was added; it was left in place at $W_PATH"
    printf 'discard it with: git -C %s worktree remove %s\n' "$W_PRIMARY" "$W_PATH" >&2
    if [ "$W_MODE" != local ]; then
      printf 'if the branch %s was newly created and is unwanted, also: git branch -D %s\n' "$W_BRANCH" "$W_BRANCH" >&2
    fi
    return 1
  fi
  release_lock

  if [ -n "${WT_SKIP_BUILD-}" ]; then
    printf 'created %s (build skipped)\n' "$W_PATH"
    return 0
  fi
  if ! make -C "$W_PATH" build; then
    wt_err "build failed; the worktree was left in place at $W_PATH"
    printf 'discard it with: make -C %s worktree-rm\n' "$W_PATH" >&2
    printf 'retry the build with: make -C %s build\n' "$W_PATH" >&2
    return 1
  fi
  printf 'created %s\n' "$W_PATH"
}

# wt_rm: remove the checkout containing the cwd (never the primary). The compose stack holds the
# shared Discord token, so a failed `down` aborts and leaves the worktree (DD-4).
wt_rm() {
  local top wt primary project img want
  top="$(git rev-parse --show-toplevel)" || return 1
  wt="$(cd -P "$top" && pwd -P)" || return 1
  primary="$(wt_primary_root)" || return 1
  if [ "$wt" = "$primary" ]; then
    wt_err "refusing to remove the primary checkout ($primary)"
    return 1
  fi
  case "$wt" in
    "$primary"/.claude/worktrees/?*)
      # Only direct children: a nested path (worktrees/x/y) is not one of ours.
      case "${wt#"$primary"/.claude/worktrees/}" in
        */*)
          wt_err "refusing to remove $wt: not a direct child of $primary/.claude/worktrees/"
          return 1
          ;;
      esac
      ;;
    *)
      wt_err "refusing to remove $wt: not under $primary/.claude/worktrees/"
      return 1
      ;;
  esac

  if project="$(rm_project "$wt")"; then
    if ! docker compose -p "$project" --project-directory "$wt/$WT_BOT_REL" -f "$wt/$WT_BOT_REL/docker-compose.yml" down; then
      wt_err "compose down failed for project '$project'; the worktree was left in place at $wt"
      printf 'start Docker and rerun: make worktree-rm\n' >&2
      printf 'or, after confirming no container of project %s is running: git -C %s worktree remove %s\n' "$project" "$primary" "$wt" >&2
      return 1
    fi
    img="$(sed -n 's/^BOT_IMAGE=//p' "$wt/.worktree.env" | tail -n 1)" || true
    want="$WT_PROJECT_PREFIX-$(basename "$wt"):local"
    if [ "$img" = "$want" ]; then
      docker image rm "$img" || wt_warn "could not remove image $img"
    else
      wt_warn "BOT_IMAGE in .worktree.env is '${img:-<unset>}', not '$want'; leaving images alone"
    fi
  fi

  # The cwd is inside the checkout being removed: step out first so git can delete it.
  cd "$primary" || return 1
  git worktree remove "$wt" || return 1
  printf 'removed %s (branch kept)\n' "$wt"
  printf 'your shell is still in the removed directory; run: cd %s\n' "$primary"
}

wt_main() {
  case "${1-}" in
    new) wt_new ;;
    rm) wt_rm ;;
    *)
      wt_err "usage: worktree.sh new|rm (WT_NAME / WT_BRANCH / WT_BASE from the environment)"
      return 2
      ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  wt_main "$@"
fi
