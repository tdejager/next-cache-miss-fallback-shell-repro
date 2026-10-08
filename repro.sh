#!/usr/bin/env bash
# Builds and runs the app twice (custom cacheHandler vs default FS cache) and
# checks a client-side navigation from / to /items/a.
set -uo pipefail
cd "$(dirname "$0")"
PORT=${PORT:-4311}

run() {
  local mode=$1
  echo "================ $mode ================"
  rm -rf .next
  if [ "$mode" = custom ]; then export CUSTOM_CACHE=1; else unset CUSTOM_CACHE; fi
  pnpm next build >build-$mode.log 2>&1 || { cat build-$mode.log; exit 2; }
  grep -E 'items' build-$mode.log
  pnpm next start -p "$PORT" >start-$mode.log 2>&1 &
  local pid=$!
  for _ in $(seq 50); do curl -sf -o /dev/null "http://localhost:$PORT/" && break; sleep 0.2; done
  node check.mjs "http://localhost:$PORT"
  local rc=$?
  kill $pid; wait $pid 2>/dev/null
  echo "--- server log ---"; grep -v '^$' start-$mode.log
  echo "exit code: $rc"
  return $rc
}

run control; control=$?
run custom; custom=$?
echo "================ summary ================"
echo "control (default cache): $([ $control = 0 ] && echo PASS || echo FAIL)"
echo "custom  (cacheHandler) : $([ $custom = 0 ] && echo PASS || echo FAIL)"
[ $custom = 0 ] && [ $control = 0 ]
