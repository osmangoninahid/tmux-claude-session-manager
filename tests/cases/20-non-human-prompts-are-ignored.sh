#!/usr/bin/env bash
set -u
. "$(dirname "$0")/../helpers.sh"

for p in '[SYSTEM NOTIFICATION - NOT USER INPUT] task-notification' '<task-notification>done</task-notification>' '/rename foo' ''; do
    out=$(hook "{\"session_id\":\"s2\",\"cwd\":\"/tmp\",\"prompt\":\"$p\"}")
    [ -z "$out" ] || { fail "output for prompt '$p': $out"; exit 1; }
    [ ! -e "$STATE/title-s2" ] || { fail "marker created for '$p'"; exit 1; }
    [ "$(session_name)" = "claude-x" ] || { fail "renamed for '$p'"; exit 1; }
done
