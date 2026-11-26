#!/usr/bin/env bash
# Launches the bundled app, checks that it stays up, samples CPU/memory, quits it
# with SIGTERM and checks that it saved town.json on the way out. Used by CI and
# handy locally after scripts/build-app.sh.
#
#   scripts/smoke-run.sh                       # normal mode, 60 s
#   scripts/smoke-run.sh -d 120 -l dev -- --dev  # developer mode (5 s ticks, 60× time)
#
# Options: -d seconds to sample (default 60), -l label for output files (default "run"),
#          -o output directory (default build/smoke). Arguments after -- go to the app.
# Outputs: <dir>/<label>.log (app stdout/stderr), <label>.csv (samples), <label>.txt (summary).
# Exit codes: 0 ok, 1 the app failed to start, crashed, hung on quit or did not save.
# Note: developer mode uses its own data folder (OddlyTown-Dev), so real progress is untouched;
#       normal mode uses and updates the real ~/Library/Application Support/OddlyTown.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_BIN="${APP_BIN:-build/Oddly Town.app/Contents/MacOS/OddlyTown}"
DURATION=60
LABEL="run"
OUTDIR="build/smoke"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d) DURATION="$2"; shift 2 ;;
    -l) LABEL="$2"; shift 2 ;;
    -o) OUTDIR="$2"; shift 2 ;;
    --) shift; break ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ ! -x "$APP_BIN" ]]; then
  echo "No app at '$APP_BIN'. Run scripts/build-app.sh first." >&2
  exit 1
fi

folder="OddlyTown"
for arg in "$@"; do [[ "$arg" == "--dev" ]] && folder="OddlyTown-Dev"; done
[[ "${ODDLY_DEV:-}" == "1" ]] && folder="OddlyTown-Dev"
TOWN_JSON="$HOME/Library/Application Support/$folder/town.json"

mkdir -p "$OUTDIR"
LOG="$OUTDIR/$LABEL.log"
marker="$(mktemp)"   # town.json must be newer than this to count as saved by this run
trap 'rm -f "$marker"' EXIT
sleep 1

fail() {
  echo "SMOKE FAILED ($LABEL): $*" >&2
  echo "--- last lines of $LOG ---" >&2
  tail -n 40 "$LOG" >&2 || true
  exit 1
}

echo "Launching $APP_BIN $* (label: $LABEL)" >&2
"$APP_BIN" "$@" >"$LOG" 2>&1 &
PID=$!

sleep 5
kill -0 "$PID" 2>/dev/null || fail "the app exited during startup"

if ! scripts/measure-resources.sh -p "$PID" -d "$DURATION" -i 5 -o "$OUTDIR/$LABEL.csv" | tee "$OUTDIR/$LABEL.txt"; then
  kill -0 "$PID" 2>/dev/null || fail "the app exited while running"
fi

kill -TERM "$PID"
for _ in $(seq 1 20); do
  kill -0 "$PID" 2>/dev/null || break
  sleep 0.5
done
if kill -0 "$PID" 2>/dev/null; then
  kill -KILL "$PID" 2>/dev/null || true
  fail "the app did not quit within 10 s of SIGTERM"
fi
wait "$PID" 2>/dev/null && code=0 || code=$?
[[ "$code" == "0" ]] || fail "the app exited with status $code after SIGTERM (expected a normal quit)"

[[ -f "$TOWN_JSON" ]] || fail "no town.json at $TOWN_JSON after quitting"
[[ "$TOWN_JSON" -nt "$marker" ]] || fail "town.json was not saved on quit"
grep -q '"schemaVersion"' "$TOWN_JSON" || fail "town.json has no schemaVersion"

echo "OK ($LABEL): ran ${DURATION}s, quit cleanly, saved $TOWN_JSON" | tee -a "$OUTDIR/$LABEL.txt"
