#!/usr/bin/env bash
# shellcheck disable=SC2154
hook() { printf '%s' "$1" | bash "$HOOK"; }
session_name() { tmux -L "$SOCKET" display-message -p -t "$TMUX_PANE" '#{session_name}'; }
fail() { echo "  assertion failed: $*" >&2; return 1; }
