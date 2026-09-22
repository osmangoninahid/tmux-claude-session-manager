#!/usr/bin/env bash
# Launch a fresh Claude session for a directory, shown in a popup.
# With @claude_reattach on, restores upstream's one-session-per-directory
# behaviour (session name = hash of the path, re-attach when it exists).
# Args: <dir> [origin-window-id]   (both expanded by run-shell in the binding)
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "$DIR/helpers.sh"

path="${1:-$PWD}"
window="${2:-}"

prefix="$(get_tmux_option @claude_session_prefix 'claude-')"
cmd="$(get_tmux_option @claude_command 'claude')"
args="$(get_tmux_option @claude_args '')"
[ -n "$args" ] && cmd="$cmd $args"
w="$(get_tmux_option @claude_popup_width '90%')"
h="$(get_tmux_option @claude_popup_height '90%')"

if [[ "$(tmux display-message -p '#S')" == "$prefix"* ]]; then
  tmux display-message '🫪 Popup window already open'
  exit 0
fi

[ -d "$path" ] || {
  tmux display-message "tmux-claude-hatch: $path no longer exists"
  exit 0
}

if [ "$(get_tmux_option @claude_reattach 'off')" = 'on' ]; then
  # Upstream behaviour: the path's hash is the lookup key — one session per
  # directory, re-attached on every launch. =name forces an exact match
  # (plain -t prefix-matches, which the suffixed names below would trip).
  session="${prefix}$(session_hash "$path")"
  if ! tmux has-session -t "=$session" 2>/dev/null; then
    tmux new-session -d -s "$session" -c "$path" "$cmd"
  fi
else
  # Every launch is a fresh session named after the directory. The counter
  # doubles as the collision check; the retry on new-session covers the race
  # where two launches allocate the same number simultaneously.
  session="$(new_session_name "$prefix" "$path")" || {
    tmux display-message 'tmux-claude-hatch: could not allocate a session name'
    exit 0
  }
  n="${session##*-}"
  base="${session%-*}"
  until tmux new-session -d -s "$session" -c "$path" "$cmd" 2>/dev/null; do
    n=$((n + 1))
    [ "$n" -gt 999 ] && {
      tmux display-message 'tmux-claude-hatch: could not allocate a session name'
      exit 0
    }
    session="${base}-${n}"
  done
fi

# Close the popup when Claude exits, even under a global detach-on-destroy off.
tmux set-option -t "$session" detach-on-destroy on

# Record which window launched it, so the picker can jump back here later.
[ -n "$window" ] && tmux set-option -t "$session" @claude_origin "$window"

title=" Agent "
tmux display-popup -w "$w" -h "$h" -b rounded -T "$title" -E "tmux attach-session -t '$session'"
