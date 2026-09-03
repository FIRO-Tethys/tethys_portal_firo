#!/usr/bin/env bash
set -euo pipefail

tethys db sync

out="$(tethys syncstores tethysdash 2>&1)"
echo "$out"
if grep -qE "Traceback|Error:|Errno" <<<"$out"; then
  echo "syncstores reported an error above but exited 0; treating as failure" >&2
  exit 1
fi
