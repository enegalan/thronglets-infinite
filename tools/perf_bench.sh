#!/usr/bin/env bash
# Automated thronglet FPS bench.
#
# Spawns N thronglets, samples FPS at zoom mid/out/in, writes shots/perf_report.json,
# exits 0 on pass / 2 on fail.
#
# Usage:
#   tools/perf_bench.sh                      # 50 thronglets, 4s/case, windowed
#   tools/perf_bench.sh 50 4                 # count, seconds
#   tools/perf_bench.sh 50 4 --headless      # CPU/frame timing without GPU
#   tools/perf_bench.sh 50 4 --busy          # mid-game props/paths/items
#   tools/perf_bench.sh 500 3 --busy --busy-scale=3
#   tools/perf_bench.sh 50 4 --busy --headless
#
# Env:
#   GODOT_BIN=/path/to/Godot

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COUNT="${1:-50}"
SECONDS_N="${2:-4}"
shift $(( $# > 0 ? 1 : 0 )) || true
shift $(( $# > 0 ? 1 : 0 )) || true
FLAGS=("$@")
GODOT="${GODOT_BIN:-}"
REPORT="$ROOT/shots/perf_report.json"
HEADLESS=0
BUSY=0
BUSY_SCALE=1
for f in "${FLAGS[@]+"${FLAGS[@]}"}"; do
  case "$f" in
    --headless) HEADLESS=1 ;;
    --busy|--perf-busy) BUSY=1 ;;
    --busy-scale=*) BUSY_SCALE="${f#--busy-scale=}" ;;
    --perf-busy-scale=*) BUSY_SCALE="${f#--perf-busy-scale=}" ;;
  esac
done

if [[ -z "$GODOT" ]]; then
  if [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
    GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
  elif command -v godot >/dev/null 2>&1; then
    GODOT="$(command -v godot)"
  else
    echo "Godot binary not found. Set GODOT_BIN." >&2
    exit 1
  fi
fi

mkdir -p "$ROOT/shots"
rm -f "$REPORT"

ARGS=(--path "$ROOT" -- --perf "--perf-count=$COUNT" "--perf-seconds=$SECONDS_N" "--perf-out=res://shots/perf_report.json")
if [[ "$BUSY" -eq 1 ]]; then
  ARGS+=(--perf-busy "--perf-busy-scale=$BUSY_SCALE")
fi
if [[ "$HEADLESS" -eq 1 ]]; then
  ARGS=(--headless "${ARGS[@]}")
  echo "Running PERF bench headless count=$COUNT busy=$BUSY scale=$BUSY_SCALE"
else
  echo "Running PERF bench windowed count=$COUNT busy=$BUSY scale=$BUSY_SCALE"
fi

set +e
"$GODOT" "${ARGS[@]}"
CODE=$?
set -e

if [[ ! -f "$REPORT" ]]; then
  echo "PERF report missing: $REPORT" >&2
  exit 1
fi

echo "---- PERF REPORT ----"
cat "$REPORT"
echo "---------------------"
echo "exit=$CODE"
exit "$CODE"
