#!/bin/bash
set -euo pipefail

WORKDIR="$1"
TEST_SCRIPT="$2"

# clean out any leftover UI cache
rm -rf "$WORKDIR/LuaUI/Config"

# locate spring-headless
if ! SPRING_BIN=$(command -v spring-headless); then
  SPRING_BIN="$ENGINE_DESTINATION/spring-headless"
fi

if [[ ! -x "$SPRING_BIN" ]]; then
  echo "!!! ERROR: spring-headless not found or not executable at '$SPRING_BIN'" >&2
  exit 1
fi

# run the test script
"$SPRING_BIN" --isolation --write-dir "$WORKDIR" "$TEST_SCRIPT"
