#!/usr/bin/env bash
# Runs the OddlyTownCore unit tests on Linux using the official Swift image.
# (The macOS app target is skipped automatically on Linux; see Package.swift.)
set -euo pipefail
cd "$(dirname "$0")/.."
IMAGE="${SWIFT_IMAGE:-swift:6.0-jammy}"
docker run --rm -v "$PWD":/src:ro -w /src "$IMAGE" \
  swift test --scratch-path /tmp/oddly-build "$@"
