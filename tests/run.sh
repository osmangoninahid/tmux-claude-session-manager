#!/usr/bin/env bash
# Runs the hook test cases against a disposable headless tmux server.
set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$TESTS_DIR/.." && pwd)"
export REPO_DIR
export HOOK="$REPO_DIR/plugins/tmux-claude-hatch/hooks/session-name.sh"

SOCKET="hatch-test-$$"
tmux -L "$SOCKET" -f /dev/null new-session -d -s claude-x -x 80 -y 24 || {
    echo "failed to start test tmux server" >&2; exit 1;
}
trap 'tmux -L "$SOCKET" kill-server 2>/dev/null || true; rm -rf "$STATE"' EXIT

TMUX="$(tmux -L "$SOCKET" display-message -p '#{socket_path}'),0,0"
TMUX_PANE="$(tmux -L "$SOCKET" display-message -p '#{pane_id}')"
STATE="$(mktemp -d)"
export TMUX TMUX_PANE SOCKET STATE
export CLAUDE_HATCH_STATE_DIR="$STATE"

pass=0
fail=0
for case_file in "$TESTS_DIR"/cases/*.sh; do
    rm -rf "$STATE"/*
    tmux -L "$SOCKET" rename-session -t "$TMUX_PANE" claude-x 2>/dev/null
    if bash "$case_file"; then
        echo "PASS $(basename "$case_file")"
        pass=$((pass + 1))
    else
        echo "FAIL $(basename "$case_file")"
        fail=$((fail + 1))
    fi
done

echo "----------------------------------------"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
