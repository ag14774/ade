#!/usr/bin/env zsh
# Live check of the worktree plugin (packages/opencode-ade-worktrees, with
# ade-kit) in the installed OpenCode: worktrees OpenCode makes and removes
# itself, through its API as the TUI's "New worktree" and the agents'
# worktree_remove do, follow the repository's layout, get a real branch and
# seeded files, and need force when they have changes. A worktree with a
# running conversation stays; once removed, its conversations move to main and
# carry on there. The service lets go of the folders that are gone (its reload
# fails on them): those removed by OpenCode or `ade worktree rm`, and, with
# `ade forget-gone`, those deleted by hand. OpenCode runs a private
# background service (its own HOME, XDG folders and port; stopped by its pid),
# with this checkout's packages; no Zellij, no model calls: a conversation
# runs while it waits on a model server of the test's that never answers.

set -u

ROOT=${0:A:h:h}
TMP=$(mktemp -d)
TMP=${TMP:A}
fail() {
  print -u2 "FAIL: $*"
  exit 1
}
step() { print -- "- $*"; }

unset -m 'OPENCODE*'
unset ZELLIJ ZELLIJ_SESSION_NAME ZELLIJ_PANE_ID ADE_CONFIG
OPENCODE=${commands[opencode]:-}
[[ -n $OPENCODE ]] || fail "opencode is not installed"
export HOME=$TMP/home TMPDIR=$TMP/tmp XDG_CONFIG_HOME=$TMP/home/.config XDG_DATA_HOME=$TMP/home/.local/share \
  XDG_STATE_HOME=$TMP/home/.local/state XDG_CACHE_HOME=$TMP/home/.cache OPENCODE_DISABLE_AUTOUPDATE=true
export GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
mkdir -p "$TMPDIR" "$XDG_CONFIG_HOME"/{opencode/plugins,ade} "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$TMP/src"
free_port() { python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])'; }
PORT=$(free_port)
PID= STALL=
trap '[[ -n $PID && $PID != null ]] && kill "$PID" 2>/dev/null; [[ -n $STALL ]] && kill "$STALL" 2>/dev/null; rm -rf "$TMP"' EXIT

# A model server that takes requests and never answers: a conversation
# prompted with its model ("stall/m") runs until it is interrupted.
STALL_PORT=$(free_port)
python3 -c '
import socket, sys
s = socket.socket()
s.bind(("127.0.0.1", int(sys.argv[1])))
s.listen(16)
held = []
while True:
    held.append(s.accept()[0])
' "$STALL_PORT" &
STALL=$!
print -r -- "{\"providers\": {\"stall\": {\"name\": \"Stall\", \"package\": \"@opencode/ai/providers/openai-compatible\",
  \"settings\": {\"apiKey\": \"x\", \"baseURL\": \"http://127.0.0.1:$STALL_PORT/v1\", \"timeout\": false, \"headerTimeout\": false},
  \"models\": {\"m\": {\"name\": \"m\"}}}}}" > "$XDG_CONFIG_HOME/opencode/opencode.json"

# OpenCode only in this HOME, with the private port in its service config.
oc() {
  [[ $HOME == $TMP/home ]] || fail "refusing to run opencode outside the test's HOME"
  [[ "$1 ${2-}" == "service set" || $(jq -r .port "$XDG_CONFIG_HOME/opencode/service.json" 2>/dev/null) == $PORT ]] \
    || fail "refusing to run opencode without the private port"
  "$OPENCODE" "$@"
}
api() { oc api "$@" 2>&1; } # the response body (and HTTP status line on errors)

# This checkout's packages, linked as npm workspaces link them (the plugin
# imports ade-kit), and ADE config.
cp -R "$ROOT/packages" "$TMP/src/"
mkdir -p "$TMP/src/node_modules"
ln -s ../packages/ade-kit "$TMP/src/node_modules/ade-kit"
ln -s "$TMP/src/packages/opencode-ade-worktrees" "$XDG_CONFIG_HOME/opencode/plugins/ade-worktrees"
cp "$ROOT/starter/ade/config.json" "$XDG_CONFIG_HOME/ade/"
ade=$TMP/src/packages/ade-kit/src/cli.ts

# A project in the bare layout: main (with a .env to seed) and feat-old, made
# by wt, where a conversation will open (OpenCode then records it as its Git
# strategy's).
git init -q -b main --bare "$TMP/origin.git"
git init -q -b main "$TMP/seed"
print '.env' > "$TMP/seed/.gitignore"
git -C "$TMP/seed" add .gitignore && git -C "$TMP/seed" commit -qm base
git -C "$TMP/seed" push -q "$TMP/origin.git" main && git --git-dir="$TMP/origin.git" symbolic-ref HEAD refs/heads/main
(cd "$TMP" && node "$ade" worktree clone "$TMP/origin.git" proj >/dev/null 2>&1) || fail "could not clone the project"
P=$TMP/proj
(cd "$P" && node "$ade" worktree open -s main >/dev/null 2>&1 && node "$ade" worktree open -s feat-old >/dev/null 2>&1) \
  || fail "could not make the project's worktrees"
print secret > "$P/main/.env"

oc service set port "$PORT" >/dev/null 2>&1
oc service start > "$TMP/service.log" 2>&1
for _ in {1..40}; do [[ -f $XDG_STATE_HOME/opencode/service.json ]] && break; sleep 1; done
PID=$(jq -r .pid "$XDG_STATE_HOME/opencode/service.json" 2>/dev/null)
[[ -n $PID && $PID != null ]] || fail "the private OpenCode service did not start: $(tail -n 5 "$TMP/service.log")"

location() { api get "/api/location?location%5Bdirectory%5D=$1"; }
loaded() { api get /api/debug/location | jq -e --arg d "$1" 'any(.[]; .directory == $d)' >/dev/null; }
project=$(location "$P/main" | jq -r .project.id)
[[ -n $project && $project != null ]] || fail "OpenCode found no project in $P/main"
location "$P/feat-old" >/dev/null
create() { api post /api/worktree -d "$(jq -cn --arg p "$project" --argjson more "$1" '{projectID: $p} + $more')"; }
removing() { api delete /api/worktree -d "$(jq -cn --arg p "$project" --arg d "$1" --argjson f "$2" '{projectID: $p, directory: $d, force: $f}')"; }
branch_of() { git -C "$1" symbolic-ref --short HEAD 2>/dev/null; }

step "a new worktree from OpenCode: wt's folder, a real branch, seeded"
out=$(create '{"name": "task-a"}')
[[ $(jq -r .directory <<< "$out" 2>/dev/null) == "$P/task-a" ]] || fail "expected $P/task-a, got: $out"
[[ $(branch_of "$P/task-a") == task-a ]] || fail "task-a should be on branch task-a"
[[ $(<"$P/task-a/.env") == secret ]] || fail "task-a should have main's .env"

step "a name with a slash keeps it in the branch; the start ref is used"
git -C "$P/main" commit -q --allow-empty -m "on main"
out=$(create '{"name": "feat/x", "branch": "main"}')
[[ $(jq -r .directory <<< "$out" 2>/dev/null) == "$P/feat-x" ]] || fail "expected $P/feat-x, got: $out"
[[ $(branch_of "$P/feat-x") == feat/x ]] || fail "feat-x should be on branch feat/x"
[[ $(git -C "$P/feat-x" rev-parse HEAD) == $(git -C "$P/main" rev-parse HEAD) ]] || fail "feat/x should start at main"

step "without a name: OpenCode's random one, as folder and branch"
out=$(create '{}')
dir=$(jq -r .directory <<< "$out" 2>/dev/null)
[[ $dir == "$P/"* && -d $dir && $(branch_of "$dir") == ${dir:t} ]] || fail "unexpected random worktree: $out"

step "OpenCode lists them all after a refresh"
api post /api/worktree/refresh -d "{\"projectID\":\"$project\"}" >/dev/null
listed=$(api get "/api/worktree?projectID=$project")
for d in task-a feat-x feat-old main; do
  [[ $(jq -r --arg d "$P/$d" '.[] | select(.directory == $d) | .strategy' <<< "$listed") == git ]] \
    || fail "$P/$d should be listed as the git strategy's: $listed"
done

step "removing: a clean worktree goes; one with changes needs force; the service lets go of both"
location "$P/task-a" >/dev/null
loaded "$P/task-a" && loaded "$P/feat-old" || fail "the service should have locations in task-a and feat-old"
out=$(removing "$P/task-a" false)
[[ ! -d $P/task-a ]] || fail "task-a should be removed: $out"
print draft > "$P/feat-old/notes.md"
out=$(removing "$P/feat-old" false)
[[ $(jq -r .data.forceRequired <<< "${out%%$'\n'HTTP*}" 2>/dev/null) == true && -d $P/feat-old ]] \
  || fail "removing feat-old with changes should ask for force: $out"
out=$(removing "$P/feat-old" true)
[[ ! -d $P/feat-old ]] || fail "feat-old should be removed with force: $out"
git -C "$P" show-ref -q --verify refs/heads/feat-old || fail "the branch should stay (as with wtrm)"
! loaded "$P/task-a" && ! loaded "$P/feat-old" || fail "the service should have let go of task-a and feat-old"

step "ade worktree rm: the service lets go of the worktree"
location "$P/feat-x" >/dev/null
out=$(cd "$P/main" && node "$ade" worktree rm feat-x 2>&1) || fail "ade worktree rm feat-x failed: $out"
! loaded "$P/feat-x" || fail "the service should have let go of feat-x: $out"

# Conversations made without a model, located in a folder ($3: more of the
# session, as JSON); their folder; whether one is running; what `pwd` prints
# in one (run as the TUI's shell mode runs it), or why it can't run.
conversation() {
  api post /api/session -d "$(jq -cn --arg d "$1" --arg t "$2" --argjson more "${3:-null}" \
    '{title: $t, location: {directory: $d}} + ($more // {})')" | jq -r .data.id
}
folder_of() { api get "/api/session/$1" | jq -r .data.location.directory; }
running() { api get /api/session/active | jq -e --arg s "$1" '.data | has($s)' >/dev/null; }
pwd_in() {
  local out ran
  out=$(api post "/api/session/$1/shell" -d '{"command": "pwd"}') || { print -r -- "$out"; return; }
  for _ in {1..20}; do
    ran=$(api get "/api/session/$1/message" | jq -r '[.data[] | select(.type == "shell")][0].output.output // empty')
    [[ -n $ran ]] && break
    sleep 0.5
  done
  print -r -- "${ran%$'\n'}"
}

step "a worktree with a running conversation stays, forced or not, through OpenCode and ade worktree rm"
out=$(create '{"name": "talk"}')
[[ $(jq -r .directory <<< "$out" 2>/dev/null) == "$P/talk" ]] || fail "expected $P/talk, got: $out"
mkdir "$P/talk/sub"
idle=$(conversation "$P/talk" "Idle talk")
child=$(conversation "$P/talk" "Its subagent" "{\"parentID\": \"$idle\"}")
deep=$(conversation "$P/talk/sub" "Deeper, archived")
api patch "/api/session/$deep" -d '{"archived": true}' >/dev/null
busy=$(conversation "$P/talk" "Busy talk" '{"model": {"id": "m", "providerID": "stall"}}')
api post "/api/session/$busy/prompt" -d '{"text": "hello"}' >/dev/null
for _ in {1..20}; do running "$busy" && break; sleep 0.5; done
running "$busy" || fail "the conversation waiting on the model should be running"
refusal='talk has a running conversation ("Busy talk"); move it out first, then remove the worktree in a later step'
for force in false true; do
  out=$(removing "$P/talk" $force)
  [[ $(jq -r '.data | "\(.message) \(.forceRequired)"' <<< "${out%%$'\n'HTTP*}" 2>/dev/null) == *"ade worktree rm: $refusal null" \
    && -d $P/talk ]] || fail "removing talk (force: $force) should be refused, without asking for force: $out"
done
out=$(cd "$P/main" && node "$ade" worktree rm -f talk 2>&1) && fail "ade worktree rm -f talk should be refused: $out"
[[ $out == "ade worktree rm: $refusal" && -d $P/talk ]] || fail "ade worktree rm -f talk should say why: $out"
[[ $(folder_of "$idle") == "$P/talk" ]] || fail "nothing should have moved yet"

step "once it is idle and removed, its conversations (a subagent's, an archived one in a subfolder) move to main and carry on there"
api post "/api/session/$busy/interrupt" >/dev/null
for _ in {1..20}; do running "$busy" || break; sleep 0.5; done
running "$busy" && fail "the interrupted conversation should be idle"
out=$(removing "$P/talk" false)
[[ ! -d $P/talk ]] || fail "talk should be removed once its conversation is idle: $out"
for s in "$idle" "$child" "$deep" "$busy"; do
  [[ $(folder_of "$s") == "$P/main" ]] || fail "conversation $s should be in main: $(api get "/api/session/$s")"
  [[ $(pwd_in "$s") == "$P/main" ]] || fail "conversation $s should run commands in main: $(pwd_in "$s")"
done
! loaded "$P/talk" || fail "the service should have let go of talk"

step "ade worktree rm: the idle conversations move to main, and it says so"
(cd "$P" && node "$ade" worktree open -s chat >/dev/null 2>&1) || fail "could not make chat"
chat=$(conversation "$P/chat" "Chat")
out=$(cd "$P/main" && node "$ade" worktree rm chat 2>&1) || fail "ade worktree rm chat failed: $out"
[[ $out == *"moved a conversation to main"* && $(folder_of "$chat") == "$P/main" ]] \
  || fail "ade worktree rm should move chat's conversation to main: $out"

step "a worktree deleted by hand: ade forget-gone lets go of it, then OpenCode's reload works"
location "$dir" >/dev/null
rm -rf "$dir"
out=$(cd "$P/main" && node "$ade" forget-gone 2>&1) || fail "ade forget-gone failed: $out"
[[ $out == "$dir" ]] || fail "ade forget-gone should print $dir: $out"
! loaded "$dir" || fail "the service should have let go of $dir"
out=$(oc reload 2>&1) || fail "OpenCode's reload should work once the service let go of $dir: $out"

print "opencode worktrees smoke test: ok"
