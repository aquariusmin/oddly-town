#!/usr/bin/env bash
# Mac: installs the app CI built from the latest green run on main (or a given run),
# so checking a change on a real Mac doesn't need a local build.
#
#   scripts/install-ci-build.sh                 # latest successful main run → /Applications
#   scripts/install-ci-build.sh -r 45836509704  # a specific run (e.g. a PR's)
#   scripts/install-ci-build.sh -d ~/Desktop    # install somewhere else
#
# Needs the GitHub CLI (`gh auth login`). Quits a running Oddly Town first.
# /Applications is the default because "Open at Login" should point at a stable location.
set -euo pipefail
cd "$(dirname "$0")/.."

RUN=""
DEST="/Applications"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -r) RUN="$2"; shift 2 ;;
    -d) DEST="$2"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ "$(uname)" == "Darwin" ]] || { echo "This installs a macOS app; run it on a Mac." >&2; exit 1; }
command -v gh >/dev/null || { echo "Install the GitHub CLI first: brew install gh && gh auth login" >&2; exit 1; }

if [[ -z "$RUN" ]]; then
  RUN="$(gh run list --workflow ci.yml --branch main --status success --limit 1 --json databaseId -q '.[0].databaseId')"
  [[ -n "$RUN" ]] || { echo "No successful CI run on main yet." >&2; exit 1; }
fi
SHA="$(gh run view "$RUN" --json headSha -q '.headSha')"
echo "CI run $RUN (commit ${SHA:0:7})"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
gh run download "$RUN" --pattern 'oddly-town-macos-*' --dir "$WORK"
ZIP="$(find "$WORK" -name 'Oddly-Town-*.zip' | head -n 1)"
[[ -n "$ZIP" ]] || { echo "That run has no app zip (did the macOS job fail before bundling?)." >&2; exit 1; }
ditto -x -k "$ZIP" "$WORK/app"

osascript -e 'tell application id "com.oddlytown.OddlyTown" to quit' >/dev/null 2>&1 || true
pkill -x OddlyTown 2>/dev/null || true
sleep 1

TARGET="$DEST/Oddly Town.app"
rm -rf "$TARGET"
ditto "$WORK/app/Oddly Town.app" "$TARGET"
xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null || true
echo "Installed $TARGET (commit ${SHA:0:7})"
echo "Open:            open \"$TARGET\""
echo "Developer mode:  \"$TARGET/Contents/MacOS/OddlyTown\" --dev"
open "$TARGET"
