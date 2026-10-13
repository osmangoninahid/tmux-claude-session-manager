#!/usr/bin/env bash
set -u
. "$(dirname "$0")/../helpers.sh"

out=$(hook '{"session_id":"s1","cwd":"/tmp","prompt":"EF-9010 size the data volume pods"}')
printf '%s' "$out" | grep -q '"sessionTitle":"EF-9010 — EF-9010 size the data volume pods"' || { fail "title: $out"; exit 1; }
[ "$(session_name)" = "claude-ef-9010-ef-9010-size-the-data-vo" ] || { fail "tmux session: $(session_name)"; exit 1; }
[ -e "$STATE/title-s1" ] || { fail "marker missing"; exit 1; }
