#!/usr/bin/env bash
set -euo pipefail

tethys db sync

rc=0
out="$(tethys syncstores tethysdash 2>&1)" || rc=$?
echo "$out"
[ "$rc" -eq 0 ] || exit "$rc"
if grep -qE "Traceback|Error:|Errno" <<<"$out"; then
  echo "syncstores reported an error above but exited 0; treating as failure" >&2
  exit 1
fi
