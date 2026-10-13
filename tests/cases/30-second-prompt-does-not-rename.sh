#!/usr/bin/env bash
set -u
. "$(dirname "$0")/../helpers.sh"

hook '{"session_id":"s3","cwd":"/tmp","prompt":"first topic"}' >/dev/null
first=$(session_name)
out=$(hook '{"session_id":"s3","cwd":"/tmp","prompt":"[SYSTEM NOTIFICATION] later noise"}')
[ -z "$out" ] || { fail "second output: $out"; exit 1; }
out=$(hook '{"session_id":"s3","cwd":"/tmp","prompt":"a completely different second prompt"}')
[ -z "$out" ] || { fail "re-titled on second prompt: $out"; exit 1; }
[ "$(session_name)" = "$first" ] || { fail "renamed on second prompt"; exit 1; }
