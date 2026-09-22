#!/usr/bin/env bash
# Name the session from the first prompt: Claude gets a sessionTitle, and a
# hatch-made tmux session (name starts with @claude_session_prefix) is renamed
# to match. Fires once per Claude session, gated by a marker file; must never
# fail the turn, so every exit path is 0 and stdout carries at most the single
# JSON object the hook contract expects.
set -u

input=$(cat 2>/dev/null) || exit 0

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$sid" ] || exit 0
marker="${TMPDIR:-/tmp}/claude-hatch-title-$sid"
[ -e "$marker" ] && exit 0

prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null |
  tr '\n\t' '  ' | tr -s ' ' | sed -E 's/^ +//; s/ +$//')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
# Physical path, so comparisons against git's output survive macOS's
# /var -> /private/var (and /tmp) symlinks.
[ -n "$cwd" ] && cwd=$(cd "$cwd" 2>/dev/null && pwd -P)

# Scope, in priority order: ticket ID in the prompt > git branch (qualified
# with repo/subpath when cwd is a monorepo subdirectory) > directory basename.
# cwd = $HOME gets no scope segment at all.
ticket=$(printf '%s' "$prompt" | grep -oE '\b[A-Z][A-Z0-9]+-[0-9]+\b' | head -n1)
scope=''
if [ -n "$ticket" ]; then
  scope=$ticket
elif [ -n "$cwd" ] && [ "$cwd" != "$HOME" ]; then
  branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ "$branch" = 'HEAD' ]; then
    branch="detached-$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)"
  fi
  if [ -n "$branch" ]; then
    scope=$branch
    root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$root" ] && [ "$cwd" != "$root" ]; then
      scope="$(basename "$root")/${cwd#"$root"/}:$branch"
    fi
  else
    scope=$(basename "$cwd")
  fi
fi

# Word-boundary truncation of the prompt slice.
short=$(printf '%s' "$prompt" | cut -c1-48)
[ "$short" != "$prompt" ] && short=$(printf '%s' "$short" | sed 's/ [^ ]*$//')

label="${scope:+$scope — }$short"
[ -n "$label" ] || exit 0

touch "$marker" 2>/dev/null

# tmux side. Only sessions this plugin launched are ever renamed: a Claude
# started loose in an ordinary pane must not rename the session you live in.
# Re-running (marker removed) re-derives the same slug, so the rename is
# idempotent — it re-labels rather than accreting suffixes.
if [ -n "${TMUX:-}" ] && [ -n "${TMUX_PANE:-}" ]; then
  prefix=$(tmux show-option -gqv @claude_session_prefix 2>/dev/null)
  prefix=${prefix:-claude-}
  cur=$(tmux display-message -p -t "$TMUX_PANE" '#{session_name}' 2>/dev/null)
  if [ -n "$cur" ] && [ "${cur#"$prefix"}" != "$cur" ]; then
    # tmux rejects '.' and ':' in session names; keep the slug to [a-z0-9-].
    slug=$(printf '%s' "${ticket:+$ticket }$short" | tr '[:upper:]' '[:lower:]' |
      sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-32 | sed -E 's/-+$//')
    if [ -n "$slug" ]; then
      new="${prefix}${slug}"
      if [ "$new" != "$cur" ] && tmux has-session -t "=$new" 2>/dev/null; then
        i=2
        while [ "$i" -le 99 ] && tmux has-session -t "=$new-$i" 2>/dev/null; do
          i=$((i + 1))
        done
        new="$new-$i"
      fi
      [ "$new" != "$cur" ] && tmux rename-session -t "$TMUX_PANE" "$new" 2>/dev/null
      tmux set-option -t "$TMUX_PANE" @claude_title "$label" 2>/dev/null
    fi
  fi
fi

printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","sessionTitle":%s}}' \
  "$(printf '%s' "$label" | jq -Rs .)"
exit 0
