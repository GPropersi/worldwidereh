#!/usr/bin/env bash
# Unit tests for scripts/worktree.sh (plain bash, no bats).
#
# Every case is a function named t_<name>, run in its own subshell against a
# throwaway git repo (with a bare origin) under mktemp -d. A stub `docker` is
# first on PATH: it records its argv to $WT_STUB_LOG, prints canned
# `docker compose ls` JSON from $WT_STUB_LS and exits 1 when $WT_STUB_FAIL is
# set. The real docker is never called. Secrets are never used (dummy values).
#
# Output: "N passed, M failed, K skipped" (counted per case); exit 1 when M > 0.

# Make/CI leak these in; every case that needs one sets it itself.
unset COMPOSE_PROJECT_NAME BOT_PORT BOT_CONTAINER BOT_IMAGE MAKELEVEL MAKEFLAGS MFLAGS
unset WT_BUSY_PORTS WT_LOCK_NOW WT_LOCK_PRE_MV WT_NO_JQ WT_SKIP_BUILD WT_STUB_LS WT_STUB_LOG WT_STUB_FAIL WT_STUB_PS WT_STUB_RC WT_STUB_FAIL_IMAGE WT_MAKE_LOG WT_MAKE_RC WT_DUMP WT_NAME WT_BRANCH WT_BASE GIT_DIR GIT_WORK_TREE

TEST_FILE="${BASH_SOURCE[0]}"
TEST_DIR="$(cd "$(dirname "$TEST_FILE")" && pwd)"
# shellcheck source=worktree.sh
source "$TEST_DIR/worktree.sh" || { echo "cannot source"; exit 1; }
# The library sets -euo pipefail; the harness manages failures itself.
set +e +u

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/worktree-test.XXXXXX")" || { echo "cannot make temp dir"; exit 1; }
ROOT="$(cd -P "$ROOT" && pwd -P)"
cleanup() { rm -rf "$ROOT"; }
trap cleanup EXIT

# ---- stub docker, first on PATH for every case ----
mkdir -p "$ROOT/stub"
cat > "$ROOT/stub/docker" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${WT_STUB_LOG:-/dev/null}"
if [ -n "${WT_STUB_FAIL:-}" ]; then exit 1; fi
if [ -n "${WT_STUB_FAIL_IMAGE:-}" ] && [ "${1:-}" = image ] && [ "${2:-}" = rm ]; then exit 1; fi
if [ "${1:-}" = compose ] && [ "${2:-}" = ls ]; then printf '%s\n' "${WT_STUB_LS:-[]}"; exit 0; fi
if [ "${1:-}" = ps ]; then printf '%s' "${WT_STUB_PS:-}"; exit 0; fi
exit "${WT_STUB_RC:-0}"
STUB
chmod +x "$ROOT/stub/docker"
export PATH="$ROOT/stub:$PATH"

# Real make, resolved before any case prepends a stub; the e2e stub make lives in its own dir
# that only the e2e cases put on PATH.
REAL_MAKE="$(command -v make)"
SCRIPT="$TEST_DIR/worktree.sh"
MAKEFILE_SRC="$TEST_DIR/../Makefile"
mkdir -p "$ROOT/stubmake"
cat > "$ROOT/stubmake/make" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "${WT_MAKE_LOG:-/dev/null}"
exit "${WT_MAKE_RC:-0}"
STUB
chmod +x "$ROOT/stubmake/make"
# Stub bash for the Makefile-level cases: records argv, dumps its environment.
mkdir -p "$ROOT/stubbash"
cat > "$ROOT/stubbash/bash" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$WT_DUMP.argv"
env > "$WT_DUMP.env"
exit 0
STUB
chmod +x "$ROOT/stubbash/bash"

# ---- assertion helpers (record into the per-case log) ----
CASE_LOG=""
mark_ok() { echo ok >> "$CASE_LOG"; }
mark_fail() { printf 'FAIL %s\n' "$1" >> "$CASE_LOG"; }
skip() { printf 'SKIP %s\n' "$1" >> "$CASE_LOG"; }
assert_eq() { # expected actual message
  if [ "$1" = "$2" ]; then mark_ok; else mark_fail "$3: expected [$1] got [$2]"; fi
}
assert_contains() { # haystack needle message
  case "$1" in *"$2"*) mark_ok ;; *) mark_fail "$3: [$1] lacks [$2]" ;; esac
}
assert_not_contains() { # haystack needle message
  case "$1" in *"$2"*) mark_fail "$3: [$1] contains [$2]" ;; *) mark_ok ;; esac
}
assert_fails() { # message cmd...
  local msg=$1
  shift
  if "$@" > /dev/null 2>&1; then mark_fail "$msg: command succeeded"; else mark_ok; fi
}
assert_succeeds() { # message cmd...
  local msg=$1
  shift
  if "$@" > /dev/null 2>&1; then mark_ok; else mark_fail "$msg: command failed"; fi
}
file_mode() { stat -c %a "$1" 2> /dev/null || stat -f %Lp "$1"; }

# ---- fixtures ----
fx_new() { # builds $FX/{origin.git,primary} and cd's into the primary
  FX="$(mktemp -d "$ROOT/fx.XXXXXX")" || return 1
  FX="$(cd -P "$FX" && pwd -P)"
  git init -q --bare -b main "$FX/origin.git"
  git init -q -b main "$FX/primary"
  git -C "$FX/primary" commit -q --allow-empty -m init
  git -C "$FX/primary" remote add origin "$FX/origin.git"
  git -C "$FX/primary" push -q origin main
  git -C "$FX/primary" remote set-head origin main
  cd "$FX/primary" || return 1
  PRIMARY="$FX/primary"
}
claim_slot() { # slot
  mkdir -p "$PRIMARY/.claude/worktrees/c$1"
  printf 'SLUG=c%s\nBOT_SLOT=%s\n' "$1" "$1" > "$PRIMARY/.claude/worktrees/c$1/.worktree.env"
}
plan_try() { # runs plan_new in this shell; PLAN_RC / PLAN_OUT
  plan_new > "$FX/plan.out" 2>&1
  PLAN_RC=$?
  PLAN_OUT="$(cat "$FX/plan.out")"
}
lock_dir() { echo "$(wt_common_dir)/worldwidereh-worktree-slot.lock"; }

# ================= cases =================

t_harness_env_clean() {
  assert_eq "" "${COMPOSE_PROJECT_NAME+set}" "COMPOSE_PROJECT_NAME not set"
  assert_eq "" "${BOT_PORT+set}" "BOT_PORT not set"
  assert_eq "" "${BOT_CONTAINER+set}" "BOT_CONTAINER not set"
  assert_eq "" "${BOT_IMAGE+set}" "BOT_IMAGE not set"
  assert_eq "" "${GIT_DIR+set}" "GIT_DIR not set"
  assert_eq "" "${GIT_WORK_TREE+set}" "GIT_WORK_TREE not set"
  assert_eq "" "${WT_STUB_RC+set}" "WT_STUB_RC not set"
  assert_eq "$ROOT/stub/docker" "$(command -v docker)" "stub docker is first on PATH"
}

t_slug_branch() {
  assert_eq "infra-worktree-adoption" "$(wt_slug infra/worktree-adoption)" "branch slug"
}
t_slug_lower_underscore() {
  assert_eq "proof-a" "$(wt_slug Proof_A)" "Proof_A"
}
t_slug_strips_leading_dash() {
  assert_eq "foo" "$(wt_slug -foo)" "single dash"
  assert_eq "foo" "$(wt_slug ---foo)" "many dashes"
  assert_eq "foo" "$(wt_slug /foo)" "leading slash"
}
t_slug_cut_then_strip_trailing() {
  local a39 in
  a39=$(printf 'a%.0s' $(seq 1 39))
  in="${a39}-bbbb"
  assert_eq "$a39" "$(wt_slug "$in")" "cut at 40 then trailing dash stripped"
  assert_eq 40 "$(wt_slug "$(printf 'x%.0s' $(seq 1 60))" | tr -d '\n' | wc -c | tr -d ' ')" "cut length"
}
t_slug_empty_is_error() {
  assert_fails "slashes only" wt_slug '///'
  assert_fails "empty" wt_slug ''
}

t_parse_name_only() {
  WT_NAME=foo wt_parse_args
  assert_eq "foo" "$W_SLUG" "slug"
  assert_eq "foo" "$W_BRANCH" "branch defaults to the slug"
  assert_eq "" "$W_BASE" "base empty"
}
t_parse_name_is_normalized() {
  WT_NAME=Proof_A wt_parse_args
  assert_eq "proof-a" "$W_SLUG" "explicit name normalized"
  assert_eq "proof-a" "$W_BRANCH" "branch defaults to the normalized slug"
}
t_parse_branch_only() {
  WT_BRANCH=infra/worktree-adoption wt_parse_args
  assert_eq "infra-worktree-adoption" "$W_SLUG" "slug from branch"
  assert_eq "infra/worktree-adoption" "$W_BRANCH" "branch kept raw"
}
t_parse_empty_means_unset() {
  WT_NAME="" WT_BRANCH=feat/x WT_BASE="" wt_parse_args
  assert_eq "feat-x" "$W_SLUG" "empty name ignored"
  assert_eq "" "$W_BASE" "empty base ignored"
}
t_parse_base_passthrough() {
  WT_NAME=foo WT_BASE=origin/dev wt_parse_args
  assert_eq "origin/dev" "$W_BASE" "base given"
}
t_parse_nothing_is_error() {
  assert_fails "no name and no branch" wt_parse_args
}

t_plan_accepts_name_only() {
  fx_new
  WT_NAME=ok plan_try
  assert_eq 0 "$PLAN_RC" "rc"
  assert_contains "$PLAN_OUT" "slug: ok" "slug printed"
  assert_eq "new" "$W_MODE" "mode"
  assert_eq "origin/main" "$W_BASE" "default base"
  assert_eq "$PRIMARY/.claude/worktrees/ok" "$W_PATH" "path"
}
t_plan_accepts_branch_only() {
  fx_new
  WT_BRANCH=infra/worktree-adoption plan_try
  assert_eq 0 "$PLAN_RC" "rc"
  assert_eq "infra-worktree-adoption" "$W_SLUG" "slug"
  assert_eq "infra/worktree-adoption" "$W_BRANCH" "branch"
}
t_plan_name_branch_same_slug_ok() {
  fx_new
  WT_NAME=Proof_A WT_BRANCH=proof/a plan_try
  assert_eq 0 "$PLAN_RC" "rc"
  assert_eq "proof-a" "$W_SLUG" "slug"
  assert_eq "proof/a" "$W_BRANCH" "branch"
}
t_plan_name_branch_mismatch_refused() {
  fx_new
  WT_NAME=foo WT_BRANCH=bar/baz plan_try
  assert_eq 1 "$PLAN_RC" "rc"
  assert_contains "$PLAN_OUT" "foo" "names the name slug"
  assert_contains "$PLAN_OUT" "bar-baz" "names the branch slug"
  assert_contains "$PLAN_OUT" "differ" "says they differ"
}
t_plan_reserved_slug_refused() {
  fx_new
  WT_NAME=worldwidereh plan_try
  assert_eq 1 "$PLAN_RC" "project name"
  assert_contains "$PLAN_OUT" "reserved" "project name reserved"
  WT_NAME=primary plan_try
  assert_eq 1 "$PLAN_RC" "primary basename"
  assert_contains "$PLAN_OUT" "reserved" "primary basename reserved"
}
t_plan_existing_path_refused() {
  fx_new
  mkdir -p "$PRIMARY/.claude/worktrees/dup"
  WT_NAME=dup plan_try
  assert_eq 1 "$PLAN_RC" "rc"
  assert_contains "$PLAN_OUT" "dup" "names the path"
  assert_contains "$PLAN_OUT" "already exists" "says it exists"
}
t_plan_bad_branch_refused() {
  fx_new
  WT_BRANCH=-x plan_try
  assert_eq 1 "$PLAN_RC" "leading dash"
  assert_contains "$PLAN_OUT" "must not start with" "leading dash message"
  WT_BRANCH=a..b plan_try
  assert_eq 1 "$PLAN_RC" "invalid ref name"
  assert_contains "$PLAN_OUT" "not a valid branch name" "invalid ref message"
}
t_plan_reflog_syntax_branch_refused() {
  fx_new
  WT_BRANCH='@{-1}' plan_try
  assert_eq 1 "$PLAN_RC" "@{-1} refused"
  assert_contains "$PLAN_OUT" "not a valid branch name" "message"
  WT_BRANCH='feat@{1}' plan_try
  assert_eq 1 "$PLAN_RC" "embedded @{ refused"
}
t_plan_leading_dash_base_refused() {
  fx_new
  WT_NAME=ok WT_BASE=--foo plan_try
  assert_eq 1 "$PLAN_RC" "rc"
  assert_contains "$PLAN_OUT" "must not start with" "message"
}
t_plan_checks_compose_ls() {
  fx_new
  export WT_STUB_LOG="$FX/docker.log"
  WT_NAME=ok plan_try
  assert_eq 0 "$PLAN_RC" "rc"
  assert_contains "$(cat "$WT_STUB_LOG")" "compose ls -a --format json" "docker compose ls -a queried"
}
t_plan_project_present_refused() {
  fx_new
  export WT_STUB_LS='[{"Name":"worldwidereh-proof-a","Status":"running(1)"}]'
  WT_NAME=proof-a plan_try
  assert_eq 1 "$PLAN_RC" "rc"
  assert_contains "$PLAN_OUT" "worldwidereh-proof-a" "names the project"
}
t_plan_near_miss_project_accepted() {
  fx_new
  export WT_STUB_LS='[{"Name":"worldwidereh-proof-ab","Status":"running(1)"}]'
  WT_NAME=proof-a plan_try
  assert_eq 0 "$PLAN_RC" "rc"
}
t_plan_docker_unavailable_warns() {
  fx_new
  export WT_STUB_FAIL=1
  WT_NAME=proof-a plan_try
  assert_eq 0 "$PLAN_RC" "does not fail"
  assert_contains "$PLAN_OUT" "docker unavailable" "warns"
}

t_project_exists_grep_branch() {
  export WT_NO_JQ=1
  export WT_STUB_LS='[{"Name":"worldwidereh-proof-ab","Status":"x"}]'
  wt_project_exists worldwidereh-proof-a 2> /dev/null
  assert_eq 1 $? "near miss absent (grep)"
  wt_project_exists worldwidereh-proof-ab 2> /dev/null
  assert_eq 0 $? "exact present (grep)"
  export WT_STUB_LS='[{"Name": "worldwidereh-proof-a","Status":"x"},{"Name":"other"}]'
  wt_project_exists worldwidereh-proof-a 2> /dev/null
  assert_eq 0 $? "spaced JSON present (grep)"
}
t_project_exists_jq_branch() {
  command -v jq > /dev/null 2>&1 || { skip "jq not installed"; return 0; }
  export WT_STUB_LS='[{"Name":"worldwidereh-proof-ab","Status":"x"}]'
  wt_project_exists worldwidereh-proof-a 2> /dev/null
  assert_eq 1 $? "near miss absent (jq)"
  wt_project_exists worldwidereh-proof-ab 2> /dev/null
  assert_eq 0 $? "exact present (jq)"
}

t_main_usage_rc2() {
  local out rc
  out="$(wt_main bogus 2>&1)"
  rc=$?
  assert_eq 2 "$rc" "rc"
  assert_contains "$out" "usage: worktree.sh new|rm" "usage text"
}

t_default_branch_from_origin_head() {
  fx_new
  git push -q origin main:develop
  git fetch -q origin
  git remote set-head origin develop
  assert_eq "develop" "$(wt_default_branch)" "origin/HEAD develop"
}
t_default_branch_fallback_main() {
  fx_new
  git remote set-head origin -d
  assert_eq "main" "$(wt_default_branch)" "fallback"
}
t_base_default_follows_origin_head() {
  fx_new
  git push -q origin main:develop
  git fetch -q origin
  git remote set-head origin develop
  WT_NAME=ok plan_try
  assert_eq 0 "$PLAN_RC" "rc"
  assert_eq "origin/develop" "$W_BASE" "base"
}
t_base_missing_errors_with_hint() {
  fx_new
  WT_NAME=ok WT_BASE=origin/nope plan_try
  assert_eq 1 "$PLAN_RC" "rc"
  assert_contains "$PLAN_OUT" "git fetch origin" "fetch hint"
  assert_contains "$PLAN_OUT" "base=" "base= hint"
}
t_base_ignored_for_existing_local_branch() {
  fx_new
  git branch feat
  WT_BRANCH=feat WT_BASE=origin/nope plan_try
  assert_eq 0 "$PLAN_RC" "rc"
  assert_eq "local" "$W_MODE" "mode"
  assert_contains "$PLAN_OUT" "ignored" "warns"
}
t_base_ignored_for_origin_only_branch() {
  fx_new
  git push -q origin main:remote-only
  git fetch -q origin
  WT_BRANCH=remote-only WT_BASE=origin/nope plan_try
  assert_eq 0 "$PLAN_RC" "rc"
  assert_eq "origin" "$W_MODE" "mode"
  assert_contains "$PLAN_OUT" "ignored" "warns"
}

t_ports_vector() {
  fx_new
  export WT_BUSY_PORTS=""
  assert_eq "68 10048" "$(alloc_slot proof-a)" "cksum vector for proof-a"
}
t_ports_vector_second() {
  fx_new
  export WT_BUSY_PORTS=""
  assert_eq "55 10035" "$(alloc_slot proof-b)" "independent cksum vector for proof-b"
}
t_ports_skips_claimed_slots() {
  fx_new
  export WT_BUSY_PORTS=""
  claim_slot 68
  assert_eq "69 10049" "$(alloc_slot proof-a)" "68 claimed"
  claim_slot 69
  assert_eq "70 10050" "$(alloc_slot proof-a)" "68 and 69 claimed"
}
t_ports_wraps_around() {
  fx_new
  export WT_BUSY_PORTS=""
  local s
  for s in $(seq 68 99); do claim_slot "$s"; done
  assert_eq "1 9981" "$(alloc_slot proof-a)" "wraps past 99 to 1"
}
t_ports_skips_busy_ports() {
  fx_new
  export WT_BUSY_PORTS="10048 10049"
  assert_eq "70 10050" "$(alloc_slot proof-a)" "busy ports skipped"
}
t_ports_ignores_ambient_env() {
  fx_new
  export WT_BUSY_PORTS=""
  export BOT_PORT=19999 COMPOSE_PROJECT_NAME=ambient
  assert_eq "68 10048" "$(alloc_slot proof-a)" "ambient BOT_PORT/COMPOSE_PROJECT_NAME ignored"
  export BOT_PORT=9980
  local out
  out="$(alloc_slot proof-a)"
  assert_eq "10048" "${out#* }" "BOT_PORT=9980 (make export) ignored"
}
t_ports_all_99_distinct_none_primary() {
  fx_new
  export WT_BUSY_PORTS=""
  local i out slots=""
  for i in $(seq 1 99); do
    out="$(alloc_slot proof-a)"
    assert_eq 0 $? "allocation $i"
    claim_slot "${out%% *}"
    slots="$slots ${out%% *}"
    assert_not_contains "$out" " 9980" "never the primary port"
    assert_eq "$((9980 + ${out%% *}))" "${out#* }" "port is 9980 + slot (allocation $i)"
  done
  assert_eq 99 "$(printf '%s\n' "$slots" | tr ' ' '\n' | grep -c . )" "99 slots collected"
  assert_eq 99 "$(printf '%s\n' "$slots" | tr ' ' '\n' | grep . | sort -u | wc -l | tr -d ' ')" "99 distinct slots"
  assert_fails "100th allocation" alloc_slot proof-a
}
t_ports_claimed_slots_never_sources() {
  fx_new
  mkdir -p "$PRIMARY/.claude/worktrees/evil"
  # shellcheck disable=SC2016 # the literal $( must reach the file unexpanded
  printf 'BOT_SLOT=5\nX=$(touch %s/pwned)\n' "$FX" > "$PRIMARY/.claude/worktrees/evil/.worktree.env"
  assert_eq "5" "$(claimed_slots "$PRIMARY")" "slot read via sed"
  assert_eq "no" "$([ -e "$FX/pwned" ] && echo yes || echo no)" "nothing executed"
}
t_ports_live_probe() {
  command -v python3 > /dev/null 2>&1 || { skip "python3 not installed (no listener)"; return 0; }
  export WT_STUB_FAIL=1
  local pf="$ROOT/probe.$$" port pid i
  python3 -c 'import socket,time
s=socket.socket()
s.bind(("127.0.0.1",0))
s.listen(1)
print(s.getsockname()[1],flush=True)
time.sleep(60)' > "$pf" &
  pid=$!
  for i in $(seq 1 100); do [ -s "$pf" ] && break; sleep 0.05; done
  port="$(cat "$pf")"
  wt_port_busy "$port"
  assert_eq 0 $? "busy while listening"
  kill "$pid" 2> /dev/null
  wait "$pid" 2> /dev/null
  wt_port_busy "$port"
  assert_eq 1 $? "free after close"
}
t_ports_live_probe_ipv6() {
  command -v python3 > /dev/null 2>&1 || { skip "python3 not installed (no listener)"; return 0; }
  export WT_STUB_FAIL=1
  local pf="$ROOT/probe6.$$" port pid i
  python3 -c 'import socket,time
try:
    s=socket.socket(socket.AF_INET6)
    s.bind(("::1",0))
except OSError:
    print("noipv6",flush=True)
    raise SystemExit
s.listen(1)
print(s.getsockname()[1],flush=True)
time.sleep(60)' > "$pf" &
  pid=$!
  for i in $(seq 1 100); do [ -s "$pf" ] && break; sleep 0.05; done
  port="$(cat "$pf")"
  if [ "$port" = "noipv6" ]; then
    wait "$pid" 2> /dev/null
    skip "no IPv6 loopback on this host"
    return 0
  fi
  wt_port_busy "$port"
  assert_eq 0 $? "busy while listening on ::1 only"
  kill "$pid" 2> /dev/null
  wait "$pid" 2> /dev/null
  wt_port_busy "$port"
  assert_eq 1 $? "free after close"
}
t_ports_docker_publish_filter() {
  export WT_STUB_PS="abc123"
  export WT_STUB_LOG="$ROOT/docker-ps.$$.log"
  : > "$WT_STUB_LOG"
  wt_port_busy 10048
  assert_eq 0 $? "docker ps reports a publisher"
  assert_contains "$(cat "$WT_STUB_LOG")" "ps --filter publish=10048 -q" "docker ps filter argv"
}
t_ports_free_when_no_publisher_no_listener() {
  export WT_STUB_PS=""
  wt_port_busy 59871
  assert_eq 1 $? "no publisher and nothing listening is free"
}

t_write_env_content_and_mode() {
  fx_new
  local wt="$PRIMARY/.claude/worktrees/proof-a"
  mkdir -p "$wt"
  write_env "$wt" proof-a 68 10048
  assert_eq 0 $? "rc"
  assert_eq "SLUG=proof-a
PRIMARY_ROOT=$PRIMARY
IS_PRIMARY=0
BOT_SLOT=68
COMPOSE_PROJECT_NAME=worldwidereh-proof-a
BOT_PORT=10048
BOT_CONTAINER=worldwidereh-proof-a-bot
BOT_IMAGE=worldwidereh-proof-a:local" "$(cat "$wt/.worktree.env")" "content"
  assert_eq 600 "$(file_mode "$wt/.worktree.env")" "mode"
  assert_eq ".worktree.env" "$(ls -A "$wt")" "no temp file left behind"
}

t_excludes_idempotent() {
  fx_new
  ensure_excludes
  ensure_excludes
  local ex
  ex="$(wt_common_dir)/info/exclude"
  assert_eq 1 "$(grep -cxF '/.worktree.env' "$ex")" "exactly one entry"
}
t_excludes_newline_safe() {
  fx_new
  local ex
  ex="$(wt_common_dir)/info/exclude"
  printf 'foo' > "$ex"
  ensure_excludes
  assert_eq "foo
/.worktree.env" "$(cat "$ex")" "no-trailing-newline file stays on separate lines"
}

t_link_env_symlinks_primary_env() {
  fx_new
  local rel=rehplacer-discord-bot/RehplacerBot wt="$PRIMARY/.claude/worktrees/w"
  mkdir -p "$PRIMARY/$rel" "$wt"
  echo 'DISCORD_TOKEN=dummy' > "$PRIMARY/$rel/.env"
  link_env "$PRIMARY" "$wt" 2> /dev/null
  assert_eq "yes" "$([ -L "$wt/$rel/.env" ] && echo yes || echo no)" "is a symlink"
  assert_eq "$PRIMARY/$rel/.env" "$(readlink "$wt/$rel/.env")" "points at the primary's file"
}
t_link_env_copies_example_with_warning() {
  fx_new
  local rel=rehplacer-discord-bot/RehplacerBot wt="$PRIMARY/.claude/worktrees/w" err
  mkdir -p "$PRIMARY/$rel" "$wt"
  echo 'DISCORD_TOKEN=' > "$PRIMARY/$rel/.env.example"
  err="$(link_env "$PRIMARY" "$wt" 2>&1 > /dev/null)"
  assert_eq "no" "$([ -L "$wt/$rel/.env" ] && echo yes || echo no)" "not a symlink"
  assert_eq "DISCORD_TOKEN=" "$(cat "$wt/$rel/.env")" "copied content"
  assert_contains "$err" "warning" "warns"
  assert_eq "yes" "$([ -f "$wt/$rel/.env" ] && [ ! -L "$wt/$rel/.env" ] && echo yes || echo no)" "regular file"
  assert_eq 600 "$(file_mode "$wt/$rel/.env")" "mode 600"
}
t_link_env_falls_back_to_worktree_example() {
  fx_new
  local rel=rehplacer-discord-bot/RehplacerBot wt="$PRIMARY/.claude/worktrees/w"
  mkdir -p "$wt/$rel"
  echo 'DISCORD_TOKEN=fromwt' > "$wt/$rel/.env.example"
  link_env "$PRIMARY" "$wt" 2> /dev/null
  assert_eq "DISCORD_TOKEN=fromwt" "$(cat "$wt/$rel/.env")" "copied from the worktree's own example"
  assert_eq "yes" "$([ -f "$wt/$rel/.env" ] && [ ! -L "$wt/$rel/.env" ] && echo yes || echo no)" "regular file"
  assert_eq 600 "$(file_mode "$wt/$rel/.env")" "mode 600"
}
t_link_env_dangling_symlink_left_alone() {
  fx_new
  local rel=rehplacer-discord-bot/RehplacerBot wt="$PRIMARY/.claude/worktrees/w"
  mkdir -p "$PRIMARY/$rel" "$wt/$rel"
  echo 'DISCORD_TOKEN=primary' > "$PRIMARY/$rel/.env"
  ln -s "$FX/nowhere" "$wt/$rel/.env"
  link_env "$PRIMARY" "$wt" 2> /dev/null
  assert_eq "$FX/nowhere" "$(readlink "$wt/$rel/.env")" "dangling link untouched"
}
t_link_env_never_clobbers() {
  fx_new
  local rel=rehplacer-discord-bot/RehplacerBot wt="$PRIMARY/.claude/worktrees/w"
  mkdir -p "$PRIMARY/$rel" "$wt/$rel"
  echo 'DISCORD_TOKEN=primary' > "$PRIMARY/$rel/.env"
  echo 'DISCORD_TOKEN=mine' > "$wt/$rel/.env"
  link_env "$PRIMARY" "$wt" 2> /dev/null
  assert_eq "DISCORD_TOKEN=mine" "$(cat "$wt/$rel/.env")" "existing real file kept"
  assert_eq "no" "$([ -L "$wt/$rel/.env" ] && echo yes || echo no)" "still a regular file"
}
t_link_env_both_missing_warns() {
  fx_new
  local rel=rehplacer-discord-bot/RehplacerBot wt="$PRIMARY/.claude/worktrees/w" err
  mkdir -p "$wt"
  err="$(link_env "$PRIMARY" "$wt" 2>&1)"
  assert_eq 0 $? "does not fail"
  assert_contains "$err" "warning" "warns"
  assert_eq "no" "$([ -e "$wt/$rel/.env" ] && echo yes || echo no)" "nothing created"
}
t_link_env_failure_propagates() {
  fx_new
  local rel=rehplacer-discord-bot/RehplacerBot wt="$PRIMARY/.claude/worktrees/w" parent rc
  parent="$wt/${rel%/*}"
  mkdir -p "$PRIMARY/$rel" "$parent"
  echo 'DISCORD_TOKEN=dummy' > "$PRIMARY/$rel/.env"
  chmod 500 "$parent"
  if [ "$(id -u)" = 0 ] || [ -w "$parent" ]; then
    chmod 700 "$parent"
    skip "cannot make a directory unwritable (root or permissive fs)"
    return 0
  fi
  link_env "$PRIMARY" "$wt" 2> /dev/null
  rc=$?
  chmod 700 "$parent"
  assert_eq 1 "$rc" "link_env returns non-zero when mkdir fails"
}

t_bind_dirs_created() {
  fx_new
  local rel=rehplacer-discord-bot/RehplacerBot wt="$PRIMARY/.claude/worktrees/w"
  mkdir -p "$wt"
  ensure_bind_dirs "$wt"
  assert_eq "yes" "$([ -d "$wt/$rel/logs" ] && echo yes || echo no)" "logs"
  assert_eq "yes" "$([ -d "$wt/$rel/commands" ] && echo yes || echo no)" "commands"
  assert_eq "yes" "$([ -O "$wt/$rel/logs" ] && echo yes || echo no)" "user-owned"
}
t_bind_dirs_idempotent() {
  fx_new
  local rel=rehplacer-discord-bot/RehplacerBot wt="$PRIMARY/.claude/worktrees/w"
  mkdir -p "$wt"
  ensure_bind_dirs "$wt"
  ensure_bind_dirs "$wt"
  assert_eq 0 $? "second run ok"
  assert_eq "yes" "$([ -d "$wt/$rel/logs" ] && [ -d "$wt/$rel/commands" ] && echo yes || echo no)" "both dirs present"
}

t_lock_acquire_release() {
  fx_new
  local d
  d="$(lock_dir)"
  acquire_lock
  assert_eq 0 $? "acquire"
  assert_eq "yes" "$([ -d "$d" ] && echo yes || echo no)" "lock dir exists"
  assert_eq "$$" "$(cat "$d/pid")" "pid file"
  release_lock
  assert_eq "no" "$([ -e "$d" ] && echo yes || echo no)" "released"
}
t_lock_second_acquire_held() {
  fx_new
  acquire_lock
  local err
  err="$(acquire_lock 2>&1)"
  assert_eq 1 $? "second acquire fails"
  assert_contains "$err" "slot lock held by pid $$" "message names the owner"
  assert_eq "yes" "$([ -d "$(lock_dir)" ] && echo yes || echo no)" "first lock intact"
}
t_lock_dead_pid_reclaimed() {
  fx_new
  local d dead
  d="$(lock_dir)"
  true &
  dead=$!
  wait "$dead"
  mkdir "$d"
  echo "$dead" > "$d/pid"
  acquire_lock
  assert_eq 0 $? "reclaimed"
  assert_eq "$$" "$(cat "$d/pid")" "now ours"
}
t_lock_pidless_old_reclaimed() {
  fx_new
  local d mt
  d="$(lock_dir)"
  mkdir "$d"
  mt="$(stat -c %Y "$d" 2> /dev/null || stat -f %m "$d")"
  export WT_LOCK_NOW=$((mt + 6))
  acquire_lock
  assert_eq 0 $? "age 6s reclaimed"
  assert_eq "$$" "$(cat "$d/pid")" "reclaimed lock's pid file is ours"
}
t_lock_pidless_exactly_5_held() {
  fx_new
  local d mt err
  d="$(lock_dir)"
  mkdir "$d"
  mt="$(stat -c %Y "$d" 2> /dev/null || stat -f %m "$d")"
  export WT_LOCK_NOW=$((mt + 5))
  err="$(acquire_lock 2>&1)"
  assert_eq 1 $? "age exactly 5s held"
  assert_contains "$err" "slot lock held" "message"
}
t_lock_release_noop_when_not_held() {
  fx_new
  local d
  d="$(lock_dir)"
  mkdir "$d"
  echo 999999 > "$d/pid"
  WT_LOCK_HELD=0
  release_lock
  assert_eq "yes" "$([ -d "$d" ] && echo yes || echo no)" "other process's lock dir kept (not held)"
  WT_LOCK_DIR="$d" WT_LOCK_HELD=1
  release_lock
  assert_eq "yes" "$([ -d "$d" ] && echo yes || echo no)" "kept when the pid file is not ours"
}
lock_swap_live_owner() { echo "$LOCK_LIVE_PID" > "$1/pid"; }
t_lock_recheck_after_mv_restores_live_owner() {
  fx_new
  local d dead err
  d="$(lock_dir)"
  true &
  dead=$!
  wait "$dead"
  mkdir "$d"
  echo "$dead" > "$d/pid"
  sleep 30 &
  LOCK_LIVE_PID=$!
  export WT_LOCK_PRE_MV=lock_swap_live_owner
  err="$(acquire_lock 2>&1)"
  assert_eq 1 $? "live owner appeared before mv: held"
  assert_contains "$err" "slot lock held by pid $LOCK_LIVE_PID" "message"
  assert_eq "$LOCK_LIVE_PID" "$(cat "$d/pid" 2> /dev/null)" "live owner's lock restored"
  assert_eq "" "$(ls -d "$d".stale-* 2> /dev/null)" "no stale dir left behind"
  kill "$LOCK_LIVE_PID" 2> /dev/null || true
  unset WT_LOCK_PRE_MV
}
lock_swap_pidless() { rm -rf "$1/pid"; }
t_lock_recheck_after_mv_restores_young_pidless_replacement() {
  fx_new
  local d dead err
  d="$(lock_dir)"
  true &
  dead=$!
  wait "$dead"
  mkdir "$d"
  echo "$dead" > "$d/pid"
  # The seam leaves a fresh pid-less dir, as a replacement acquirer would before writing its pid.
  export WT_LOCK_PRE_MV=lock_swap_pidless
  err="$(acquire_lock 2>&1)"
  assert_eq 1 $? "young pid-less replacement: held"
  assert_contains "$err" "slot lock held" "message"
  case "$err" in *"by pid"*) assert_eq "no by-pid suffix" "$err" "pid-less message has no suffix" ;; esac
  assert_eq "yes" "$([ -d "$d" ] && echo yes || echo no)" "replacement's lock restored"
  assert_eq "no" "$([ -e "$d/pid" ] && echo yes || echo no)" "restored dir is still pid-less"
  assert_eq "" "$(ls -d "$d".stale-* 2> /dev/null)" "no stale dir left behind"
  unset WT_LOCK_PRE_MV
}
t_lock_pidless_young_held() {
  fx_new
  local d mt err
  d="$(lock_dir)"
  mkdir "$d"
  mt="$(stat -c %Y "$d" 2> /dev/null || stat -f %m "$d")"
  export WT_LOCK_NOW=$((mt + 4))
  err="$(acquire_lock 2>&1)"
  assert_eq 1 $? "age 4s held"
  assert_contains "$err" "slot lock held" "message"
  case "$err" in *"by pid"*) assert_eq "no by-pid suffix" "$err" "pid-less message has no suffix" ;; esac
}
t_lock_stat_failure_treated_as_stale() {
  fx_new
  local d
  d="$(lock_dir)"
  mkdir "$d"
  # shellcheck disable=SC2329 # invoked by acquire_lock, overriding the sourced helper
  wt_mtime() { return 1; }
  acquire_lock
  assert_eq 0 $? "failed stat falls through to the mv reclaim"
  assert_eq "$$" "$(cat "$d/pid")" "reclaimed lock's pid file is ours"
  assert_eq "" "$(ls -d "$d".stale-* 2> /dev/null)" "no stale dir left behind"
}
lock_swap_vanish() { rm -rf "$1"; }
t_lock_vanished_before_mv_reports_held() {
  fx_new
  local d dead err
  d="$(lock_dir)"
  true &
  dead=$!
  wait "$dead"
  mkdir "$d"
  echo "$dead" > "$d/pid"
  export WT_LOCK_PRE_MV=lock_swap_vanish
  err="$(acquire_lock 2>&1)"
  assert_eq 1 $? "mv loser reports held"
  assert_contains "$err" "slot lock held" "message"
  assert_eq "" "$(ls -d "$d".stale-* 2> /dev/null)" "no stale dir left behind"
  unset WT_LOCK_PRE_MV
}

t_rm_project_file_missing() {
  fx_new
  local wt="$PRIMARY/.claude/worktrees/proof-a" out
  mkdir -p "$wt"
  out="$(rm_project "$wt" 2> /dev/null)"
  assert_eq 1 $? "rc"
  assert_eq "" "$out" "no project"
}
t_rm_project_mismatch() {
  fx_new
  local wt="$PRIMARY/.claude/worktrees/proof-a" out
  mkdir -p "$wt"
  echo 'COMPOSE_PROJECT_NAME=worldwidereh-other' > "$wt/.worktree.env"
  out="$(rm_project "$wt" 2> /dev/null)"
  assert_eq 1 $? "rc"
  assert_eq "" "$out" "no project"
}
t_rm_project_primary_value_skipped() {
  fx_new
  local wt="$PRIMARY/.claude/worktrees/proof-a" out
  mkdir -p "$wt"
  echo 'COMPOSE_PROJECT_NAME=worldwidereh' > "$wt/.worktree.env"
  out="$(rm_project "$wt" 2> /dev/null)"
  assert_eq 1 $? "rc"
  assert_eq "" "$out" "never the primary project"
}
t_rm_project_ambient_env_ignored() {
  fx_new
  local wt="$PRIMARY/.claude/worktrees/proof-a" out
  mkdir -p "$wt"
  export COMPOSE_PROJECT_NAME=worldwidereh-proof-a
  out="$(rm_project "$wt" 2> /dev/null)"
  assert_eq 1 $? "matching-looking ambient value, no file"
  assert_eq "" "$out" "no project"
  echo 'COMPOSE_PROJECT_NAME=worldwidereh-other' > "$wt/.worktree.env"
  export COMPOSE_PROJECT_NAME=worldwidereh-proof-a
  out="$(rm_project "$wt" 2> /dev/null)"
  assert_eq 1 $? "ambient cannot rescue a mismatching file"
  assert_eq "" "$out" "ambient cannot rescue: no output"
  echo 'COMPOSE_PROJECT_NAME=worldwidereh-proof-a' > "$wt/.worktree.env"
  export COMPOSE_PROJECT_NAME=ambient
  out="$(rm_project "$wt" 2> /dev/null)"
  assert_eq "worldwidereh-proof-a" "$out" "different ambient value cannot override the file"
}
t_rm_project_key_absent() {
  fx_new
  local wt="$PRIMARY/.claude/worktrees/proof-a" out
  mkdir -p "$wt"
  echo 'SLUG=proof-a' > "$wt/.worktree.env"
  out="$(rm_project "$wt" 2> /dev/null)"
  assert_eq 1 $? "rc"
  assert_eq "" "$out" "no project"
}
t_rm_project_empty_value() {
  fx_new
  local wt="$PRIMARY/.claude/worktrees/proof-a" out
  mkdir -p "$wt"
  echo 'COMPOSE_PROJECT_NAME=' > "$wt/.worktree.env"
  out="$(rm_project "$wt" 2> /dev/null)"
  assert_eq 1 $? "rc"
  assert_eq "" "$out" "no project"
}
t_rm_project_last_line_wins() {
  fx_new
  local wt="$PRIMARY/.claude/worktrees/proof-a" out
  mkdir -p "$wt"
  printf 'COMPOSE_PROJECT_NAME=worldwidereh-proof-a\nCOMPOSE_PROJECT_NAME=worldwidereh-other\n' > "$wt/.worktree.env"
  out="$(rm_project "$wt" 2> /dev/null)"
  assert_eq 1 $? "mismatching last line skipped"
  assert_eq "" "$out" "no project"
  printf 'COMPOSE_PROJECT_NAME=worldwidereh-other\nCOMPOSE_PROJECT_NAME=worldwidereh-proof-a\n' > "$wt/.worktree.env"
  out="$(rm_project "$wt" 2> /dev/null)"
  assert_eq 0 $? "matching last line ok"
  assert_eq "worldwidereh-proof-a" "$out" "project"
}
t_rm_project_match() {
  fx_new
  local wt="$PRIMARY/.claude/worktrees/proof-a" out
  mkdir -p "$wt"
  printf 'SLUG=proof-a\nCOMPOSE_PROJECT_NAME=worldwidereh-proof-a\n' > "$wt/.worktree.env"
  out="$(rm_project "$wt" 2> /dev/null)"
  assert_eq 0 $? "rc"
  assert_eq "worldwidereh-proof-a" "$out" "project"
}

# ---- Step 4: new / rm end-to-end (stub docker, stub make, no real build) ----

BOT_REL=rehplacer-discord-bot/RehplacerBot
fx_e2e() { # fx_new plus a dummy primary .env (excluded, like the repo's .gitignore does)
  fx_new || return 1
  mkdir -p "$PRIMARY/$BOT_REL"
  echo 'DISCORD_TOKEN=dummy' > "$PRIMARY/$BOT_REL/.env"
  printf '.env\n' >> "$(wt_common_dir)/info/exclude"
}
run_in() { # run_in <dir> cmd...: RUN_RC / RUN_OUT (stdout+stderr)
  local d=$1
  shift
  (cd "$d" && "$@") > "$FX/run.out" 2>&1
  RUN_RC=$?
  RUN_OUT="$(cat "$FX/run.out")"
}
mk_wt() { # mk_wt <name> [branch]: create a worktree without building
  WT_NAME=$1 WT_BRANCH=${2-} WT_SKIP_BUILD=1 run_in "$PRIMARY" bash "$SCRIPT" new
}
yesno() { if "$@"; then echo yes; else echo no; fi; }

t_new_creates_worktree_new_branch() {
  fx_e2e
  local wt="$PRIMARY/.claude/worktrees/proof-a"
  export WT_MAKE_LOG="$FX/make.log"
  PATH="$ROOT/stubmake:$PATH" mk_wt proof-a proof/a
  assert_eq 0 "$RUN_RC" "rc ($RUN_OUT)"
  assert_eq "proof/a" "$(git -C "$wt" branch --show-current)" "on the new branch"
  assert_eq "$(git rev-parse origin/main)" "$(git rev-parse proof/a)" "cut from the base"
  git config --get branch.proof/a.remote > /dev/null
  assert_eq 1 $? "no upstream (--no-track)"
  assert_contains "$(cat "$wt/.worktree.env")" "COMPOSE_PROJECT_NAME=worldwidereh-proof-a" "env file written"
  assert_eq "$PRIMARY/$BOT_REL/.env" "$(readlink "$wt/$BOT_REL/.env")" ".env linked"
  assert_eq "yes" "$(yesno test -d "$wt/$BOT_REL/logs" -a -d "$wt/$BOT_REL/commands")" "bind dirs"
  assert_eq "no" "$(yesno test -e "$FX/make.log")" "build skipped: make never called"
  assert_eq "no" "$(yesno test -e "$(wt_common_dir)/worldwidereh-worktree-slot.lock")" "lock released"
}
t_new_runs_build_never_up() {
  fx_e2e
  local wt="$PRIMARY/.claude/worktrees/proof-a"
  export WT_MAKE_LOG="$FX/make.log"
  WT_NAME=proof-a PATH="$ROOT/stubmake:$PATH" run_in "$PRIMARY" bash "$SCRIPT" new
  assert_eq 0 "$RUN_RC" "rc ($RUN_OUT)"
  assert_eq "-C $wt build" "$(cat "$WT_MAKE_LOG")" "only the build was invoked"
  assert_not_contains "$(cat "$WT_MAKE_LOG")" " up" "never up"
}
t_new_build_failure_keeps_worktree() {
  fx_e2e
  local wt="$PRIMARY/.claude/worktrees/proof-a"
  export WT_MAKE_LOG="$FX/make.log" WT_MAKE_RC=2
  WT_NAME=proof-a PATH="$ROOT/stubmake:$PATH" run_in "$PRIMARY" bash "$SCRIPT" new
  assert_eq 1 "$RUN_RC" "rc"
  assert_eq "yes" "$(yesno test -d "$wt")" "worktree left in place"
  assert_contains "$RUN_OUT" "make -C $wt worktree-rm" "discard command"
  assert_contains "$RUN_OUT" "make -C $wt build" "retry command"
}
t_new_existing_local_branch_attached() {
  fx_e2e
  git branch feat
  git commit -q --allow-empty -m later
  local old wt="$PRIMARY/.claude/worktrees/feat"
  old="$(git rev-parse feat)"
  WT_BASE=origin/nope mk_wt feat feat
  assert_eq 0 "$RUN_RC" "rc ($RUN_OUT)"
  assert_eq "feat" "$(git -C "$wt" branch --show-current)" "attached"
  assert_eq "$old" "$(git rev-parse feat)" "old tip kept"
  assert_contains "$RUN_OUT" "ignored" "base ignored with a warning"
}
t_new_origin_only_branch_tracks() {
  fx_e2e
  git push -q origin main:remote-only
  git fetch -q origin
  local wt="$PRIMARY/.claude/worktrees/remote-only"
  WT_BASE=origin/nope mk_wt remote-only remote-only
  assert_eq 0 "$RUN_RC" "rc ($RUN_OUT)"
  assert_contains "$RUN_OUT" "ignored" "base ignored with a warning"
  assert_eq "remote-only" "$(git -C "$wt" branch --show-current)" "on the branch"
  assert_eq "origin" "$(git config --get branch.remote-only.remote)" "tracks origin"
  assert_eq "refs/heads/remote-only" "$(git config --get branch.remote-only.merge)" "merge set"
}
t_new_setup_failure_leaves_worktree() {
  fx_e2e
  local s wt="$PRIMARY/.claude/worktrees/ok"
  export WT_BUSY_PORTS=""
  for s in $(seq 1 99); do claim_slot "$s"; done
  mk_wt ok
  assert_eq 1 "$RUN_RC" "rc"
  assert_eq "yes" "$(yesno test -d "$wt")" "worktree left in place"
  assert_eq "no" "$(yesno test -e "$(wt_common_dir)/worldwidereh-worktree-slot.lock")" "lock released"
  assert_contains "$RUN_OUT" "git -C $PRIMARY worktree remove $wt" "exact discard command"
  assert_not_contains "$RUN_OUT" "--force" "never suggests force"
  assert_contains "$RUN_OUT" "git branch -D ok" "newly created branch discard note"
  assert_contains "$RUN_OUT" "no free port slot" "names slot exhaustion"
}
t_new_from_linked_worktree() {
  fx_e2e
  mk_wt first
  assert_eq 0 "$RUN_RC" "first ($RUN_OUT)"
  WT_NAME=second WT_SKIP_BUILD=1 run_in "$PRIMARY/.claude/worktrees/first" bash "$SCRIPT" new
  assert_eq 0 "$RUN_RC" "second ($RUN_OUT)"
  local wt="$PRIMARY/.claude/worktrees/second"
  assert_eq "yes" "$(yesno test -d "$wt")" "lands under the primary"
  assert_eq "no" "$(yesno test -e "$PRIMARY/.claude/worktrees/first/.claude")" "not nested in the caller"
  assert_eq "$PRIMARY/$BOT_REL/.env" "$(readlink "$wt/$BOT_REL/.env")" ".env points at the primary's file"
  assert_eq 1 "$(grep -cxF '/.worktree.env' "$PRIMARY/.git/info/exclude")" "exclude entry in the common dir"
  assert_eq "no" "$(yesno test -e "$PRIMARY/.git/worldwidereh-worktree-slot.lock")" "lock (common dir) released"
}

t_rm_full_flow() {
  fx_e2e
  local wt="$PRIMARY/.claude/worktrees/proof-a" bot log
  bot="$wt/$BOT_REL"
  mk_wt proof-a proof/a
  export WT_STUB_LOG="$FX/docker-rm.log"
  : > "$WT_STUB_LOG"
  run_in "$wt" bash "$SCRIPT" rm
  assert_eq 0 "$RUN_RC" "rc ($RUN_OUT)"
  log="$(cat "$WT_STUB_LOG")"
  assert_eq "compose -p worldwidereh-proof-a --project-directory $bot -f $bot/docker-compose.yml down
image rm worldwidereh-proof-a:local" "$log" "exact docker argv, in order"
  assert_eq "no" "$(yesno test -e "$wt")" "worktree removed"
  assert_eq "yes" "$(yesno git show-ref --verify --quiet refs/heads/proof/a)" "branch kept"
}
t_rm_skip_when_project_mismatch() {
  fx_e2e
  local wt="$PRIMARY/.claude/worktrees/proof-a"
  mk_wt proof-a
  sed -i.bak 's/^COMPOSE_PROJECT_NAME=.*/COMPOSE_PROJECT_NAME=worldwidereh/' "$wt/.worktree.env"
  rm -f "$wt/.worktree.env.bak"
  export WT_STUB_LOG="$FX/docker-rm.log"
  : > "$WT_STUB_LOG"
  run_in "$wt" bash "$SCRIPT" rm
  assert_eq 0 "$RUN_RC" "rc ($RUN_OUT)"
  assert_eq "" "$(cat "$WT_STUB_LOG")" "docker never called"
  assert_contains "$RUN_OUT" "skipping the docker step" "warns"
  assert_eq "no" "$(yesno test -e "$wt")" "worktree still removed"
}
t_rm_refuses_primary() {
  fx_e2e
  run_in "$PRIMARY" bash "$SCRIPT" rm
  assert_eq 1 "$RUN_RC" "rc"
  assert_contains "$RUN_OUT" "primary" "message"
  assert_eq "yes" "$(yesno test -d "$PRIMARY/.git")" "primary intact"
}
t_rm_refuses_path_outside_worktrees() {
  fx_e2e
  git worktree add -q -b other "$FX/elsewhere"
  run_in "$FX/elsewhere" bash "$SCRIPT" rm
  assert_eq 1 "$RUN_RC" "rc"
  assert_contains "$RUN_OUT" "not under" "message"
  assert_eq "yes" "$(yesno test -d "$FX/elsewhere")" "left in place"
}
t_rm_refuses_nested_path() {
  fx_e2e
  local nested="$PRIMARY/.claude/worktrees/x/y"
  git worktree add -q -b nested "$nested"
  run_in "$nested" bash "$SCRIPT" rm
  assert_eq 1 "$RUN_RC" "rc"
  assert_contains "$RUN_OUT" "not a direct child" "message"
  assert_eq "yes" "$(yesno test -d "$nested")" "left in place"
}
t_rm_without_force_keeps_dirty_worktree() {
  fx_e2e
  local wt="$PRIMARY/.claude/worktrees/proof-a"
  mk_wt proof-a
  echo stray > "$wt/stray.txt"
  run_in "$wt" bash "$SCRIPT" rm
  assert_eq 1 "$RUN_RC" "rc"
  assert_eq "yes" "$(yesno test -d "$wt")" "worktree stays"
  assert_contains "$RUN_OUT" "untracked" "git's error surfaced"
  assert_not_contains "$RUN_OUT" "removed $wt" "no success message"
}
t_rm_success_prints_cd_hint() {
  fx_e2e
  local wt="$PRIMARY/.claude/worktrees/proof-a"
  mk_wt proof-a
  run_in "$wt" bash "$SCRIPT" rm
  assert_eq 0 "$RUN_RC" "rc ($RUN_OUT)"
  assert_contains "$RUN_OUT" "cd $PRIMARY" "cd hint"
}
t_rm_down_failure_is_fatal() {
  fx_e2e
  local wt="$PRIMARY/.claude/worktrees/proof-a"
  mk_wt proof-a
  WT_STUB_FAIL=1 run_in "$wt" bash "$SCRIPT" rm
  assert_eq 1 "$RUN_RC" "rc"
  assert_eq "yes" "$(yesno test -d "$wt")" "worktree left in place (DD-4)"
  assert_contains "$RUN_OUT" "start Docker and rerun" "fallback one"
  assert_contains "$RUN_OUT" "git -C $PRIMARY worktree remove $wt" "fallback two"
}
t_rm_image_failure_only_warns() {
  fx_e2e
  local wt="$PRIMARY/.claude/worktrees/proof-a"
  mk_wt proof-a
  WT_STUB_FAIL_IMAGE=1 run_in "$wt" bash "$SCRIPT" rm
  assert_eq 0 "$RUN_RC" "rc ($RUN_OUT)"
  assert_contains "$RUN_OUT" "could not remove image" "warns"
  assert_eq "no" "$(yesno test -e "$wt")" "worktree removed"
}
t_rm_foreign_image_not_removed() {
  fx_e2e
  local wt="$PRIMARY/.claude/worktrees/proof-a"
  mk_wt proof-a
  sed -i.bak 's/^BOT_IMAGE=.*/BOT_IMAGE=rehplacer-bot:latest/' "$wt/.worktree.env"
  rm -f "$wt/.worktree.env.bak"
  export WT_STUB_LOG="$FX/docker-rm.log"
  : > "$WT_STUB_LOG"
  run_in "$wt" bash "$SCRIPT" rm
  assert_eq 0 "$RUN_RC" "rc ($RUN_OUT)"
  assert_contains "$(cat "$WT_STUB_LOG")" "compose -p worldwidereh-proof-a" "down ran"
  assert_not_contains "$(cat "$WT_STUB_LOG")" "image rm" "shared image untouched"
  assert_eq "no" "$(yesno test -e "$wt")" "worktree removed"
}
t_rm_empty_image_not_removed() {
  fx_e2e
  local wt="$PRIMARY/.claude/worktrees/proof-a"
  mk_wt proof-a
  sed -i.bak '/^BOT_IMAGE=/d' "$wt/.worktree.env"
  rm -f "$wt/.worktree.env.bak"
  export WT_STUB_LOG="$FX/docker-rm.log"
  : > "$WT_STUB_LOG"
  run_in "$wt" bash "$SCRIPT" rm
  assert_eq 0 "$RUN_RC" "rc ($RUN_OUT)"
  assert_contains "$(cat "$WT_STUB_LOG")" "compose -p worldwidereh-proof-a" "down ran"
  assert_not_contains "$(cat "$WT_STUB_LOG")" "image rm" "no image removal"
  assert_eq "no" "$(yesno test -e "$wt")" "worktree removed"
}

# ---- Step 4: Makefile-level cases (real make, stub bash first on PATH) ----

mk_dir() { # a temp dir holding a copy of the Makefile; MD
  MD="$(mktemp -d "$ROOT/mk.XXXXXX")"
  cp "$MAKEFILE_SRC" "$MD/Makefile"
  export WT_DUMP="$MD/dump"
}
make_stubbed() { # make_stubbed args...: real make, stub bash on PATH
  (cd "$MD" && PATH="$ROOT/stubbash:$PATH" "$REAL_MAKE" --no-print-directory "$@") > "$MD/make.out" 2>&1
  MK_RC=$?
}
t_make_quoting_roundtrip() {
  mk_dir
  make_stubbed worktree-new name="a'b" b="x y"
  assert_eq 0 "$MK_RC" "rc ($(cat "$MD/make.out"))"
  assert_eq "WT_NAME=a'b" "$(grep '^WT_NAME=' "$WT_DUMP.env")" "name round-trips"
  assert_eq "WT_BRANCH=x y" "$(grep '^WT_BRANCH=' "$WT_DUMP.env")" "branch round-trips"
  assert_eq "scripts/worktree.sh new" "$(cat "$WT_DUMP.argv")" "script and subcommand"
  rm -f "$WT_DUMP.env" "$WT_DUMP.argv"
  make_stubbed worktree-new name="'x y'"
  assert_eq "WT_NAME='x y'" "$(grep '^WT_NAME=' "$WT_DUMP.env")" "quoted value kept as typed"
}
t_make_base_quoting_roundtrip() {
  mk_dir
  make_stubbed worktree-new name=ok base="o'r z"
  assert_eq 0 "$MK_RC" "rc ($(cat "$MD/make.out"))"
  assert_eq "WT_BASE=o'r z" "$(grep '^WT_BASE=' "$WT_DUMP.env")" "base round-trips"
}
t_make_new_does_not_leak_identity() {
  mk_dir
  make_stubbed worktree-new name=ok
  assert_eq 0 "$MK_RC" "rc"
  assert_eq "yes" "$(yesno test -s "$WT_DUMP.env")" "stub saw an environment"
  assert_eq 0 "$(grep -cE '^(BOT_PORT|COMPOSE_PROJECT_NAME|BOT_CONTAINER|BOT_IMAGE)=' "$WT_DUMP.env")" "none of the four exported"
}
t_make_rm_exports_identity_positive_control() {
  mk_dir
  make_stubbed worktree-rm
  assert_eq 0 "$MK_RC" "rc"
  assert_eq 4 "$(grep -cE '^(BOT_PORT|COMPOSE_PROJECT_NAME|BOT_CONTAINER|BOT_IMAGE)=' "$WT_DUMP.env")" "all four exported to worktree-rm"
  assert_eq "scripts/worktree.sh rm" "$(cat "$WT_DUMP.argv")" "script and subcommand"
}
t_make_environment_beats_file() {
  mk_dir
  printf 'COMPOSE_PROJECT_NAME=filep\nBOT_PORT=19001\n' > "$MD/.worktree.env"
  local out
  out="$(cd "$MD" && "$REAL_MAKE" --no-print-directory worktree-ports)"
  assert_contains "$out" "COMPOSE_PROJECT_NAME=filep" "file beats default"
  assert_contains "$out" "BOT_PORT=19001" "file beats default"
  out="$(cd "$MD" && COMPOSE_PROJECT_NAME=envp BOT_PORT=19002 "$REAL_MAKE" --no-print-directory worktree-ports)"
  assert_contains "$out" "COMPOSE_PROJECT_NAME=envp" "environment beats file"
  assert_contains "$out" "BOT_PORT=19002" "environment beats file"
}
t_make_defaults_without_env_file() {
  mk_dir
  local out
  out="$(cd "$MD" && "$REAL_MAKE" --no-print-directory worktree-ports)"
  assert_eq "BOT_PORT=9980
COMPOSE_PROJECT_NAME=worldwidereh" "$out" "defaults, exact"
}
t_make_tampered_env_values_fall_back() {
  mk_dir
  printf 'COMPOSE_PROJECT_NAME=x; touch %s/pwned\nBOT_PORT=%s\nBOT_CONTAINER=a b\nBOT_IMAGE=img:local\n' "$MD" "\$(id)" > "$MD/.worktree.env"
  local out
  out="$(cd "$MD" && "$REAL_MAKE" --no-print-directory worktree-ports)"
  assert_eq "BOT_PORT=9980
COMPOSE_PROJECT_NAME=worldwidereh" "$out" "tampered values fall back to defaults"
  assert_eq "no" "$(yesno test -e "$MD/pwned")" "injected command never ran"
  printf 'BOT_PORT=19001\nBOT_PORT=bad;x\nBOT_PORT=-1\n' > "$MD/.worktree.env"
  out="$(cd "$MD" && "$REAL_MAKE" --no-print-directory worktree-ports)"
  assert_contains "$out" "BOT_PORT=19001" "invalid later line ignored, last valid wins"
}
t_make_command_line_beats_all() {
  mk_dir
  printf 'COMPOSE_PROJECT_NAME=filep\nBOT_PORT=19001\n' > "$MD/.worktree.env"
  local out
  out="$(cd "$MD" && COMPOSE_PROJECT_NAME=envp BOT_PORT=19002 "$REAL_MAKE" --no-print-directory worktree-ports BOT_PORT=19003 COMPOSE_PROJECT_NAME=cmdp)"
  assert_contains "$out" "BOT_PORT=19003" "command line beats environment and file"
  assert_contains "$out" "COMPOSE_PROJECT_NAME=cmdp" "command line beats environment and file"
}

# ================= runner =================

PASSED=0
FAILED=0
SKIPPED=0
RAN=0
CASES="$(grep -o '^t_[A-Za-z0-9_]*()' "$TEST_FILE" | tr -d '()')"
for fn in $CASES; do
  CASE_LOG="$(mktemp "$ROOT/case.XXXXXX")"
  ( set +e; cd "$ROOT" && "$fn" )
  if grep -q '^FAIL' "$CASE_LOG"; then
    FAILED=$((FAILED + 1))
    echo "FAIL $fn"
    grep '^FAIL' "$CASE_LOG" | sed 's/^/    /'
  elif grep -q '^SKIP' "$CASE_LOG"; then
    SKIPPED=$((SKIPPED + 1))
    echo "SKIP $fn: $(grep '^SKIP' "$CASE_LOG" | head -n 1 | sed 's/^SKIP //')"
  elif grep -q '^ok' "$CASE_LOG"; then
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
    echo "FAIL $fn: no assertions ran (case crashed?)"
  fi
  RAN=$((RAN + 1))
done

EXPECTED="$(grep -c '^t_' "$TEST_FILE")"
if [ "$RAN" -ne "$EXPECTED" ]; then
  FAILED=$((FAILED + 1))
  echo "FAIL runner: ran $RAN cases but the file declares $EXPECTED"
fi

echo "$PASSED passed, $FAILED failed, $SKIPPED skipped"
[ "$FAILED" -eq 0 ]
