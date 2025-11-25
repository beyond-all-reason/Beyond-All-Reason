#!/bin/bash
set -euo pipefail

mkdir -p "$ENGINE_DESTINATION"

TEMP_FILE=$(mktemp --suffix=.7z)
cleanup() { rm -f "$TEMP_FILE"; }
trap cleanup EXIT

# Retry download a few times and fail fast on HTTP errors (GitHub can occasionally serve HTML error pages).
curl -fL --retry 5 --retry-delay 2 --retry-all-errors "$ENGINE_URL" -o "$TEMP_FILE"

# Validate the archive before extracting so we don't proceed with a bad download.
7z t "$TEMP_FILE" >/dev/null
7z x "$TEMP_FILE" -o"$ENGINE_DESTINATION"
