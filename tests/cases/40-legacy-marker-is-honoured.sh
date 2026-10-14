#!/usr/bin/env bash
set -u
. "$(dirname "$0")/../helpers.sh"

legacy_dir="$(mktemp -d)"
touch "$legacy_dir/claude-hatch-title-s4"
out=$(TMPDIR="$legacy_dir" hook '{"session_id":"s4","cwd":"/tmp","prompt":"a later prompt"}')
rm -rf "$legacy_dir"
[ -z "$out" ] || { fail "re-titled despite legacy marker: $out"; exit 1; }
[ "$(session_name)" = "claude-x" ] || { fail "renamed despite legacy marker"; exit 1; }
[ -e "$STATE/title-s4" ] || { fail "legacy marker not migrated"; exit 1; }
