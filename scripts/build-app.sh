#!/usr/bin/env bash
# Builds "build/Oddly Town.app" (menu-bar app, no Dock icon) from the Swift package.
#   scripts/build-app.sh              # release, native arch
#   UNIVERSAL=1 scripts/build-app.sh  # arm64 + x86_64
#   CONFIG=debug scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
ARCH_FLAGS=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

# ${ARCH_FLAGS[@]+...} keeps `set -u` happy with an empty array on macOS's bash 3.2.
swift build -c "$CONFIG" --product OddlyTown ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c "$CONFIG" --product OddlyTown ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

APP="build/Oddly Town.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/OddlyTown" "$APP/Contents/MacOS/OddlyTown"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -d Resources/Art ]]; then
  cp -R Resources/Art "$APP/Contents/Resources/Art"
fi

# Ad-hoc signature so Gatekeeper treats it as a locally built app.
codesign --force --sign - "$APP"
echo "Built: $APP"
echo "Run:   open \"$APP\"    (developer mode: \"$APP/Contents/MacOS/OddlyTown\" --dev)"
