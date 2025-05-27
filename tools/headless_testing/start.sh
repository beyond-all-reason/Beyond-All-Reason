#!/bin/bash
set -euo pipefail
# ------------------------------------------------------------
#  start.sh — thin wrapper to launch spring-headless for tests
#
#  Usage:
#     ./start.sh [WORKDIR] [SCRIPT]
#  If no args are given it will:
#     • write   to /tmp/bar-headless-$(id -u)/
#     • run     ./tests/test_t2_transporter_capacity.lua
# ------------------------------------------------------------

# ---------- 1. parameter handling ----------
WORKDIR="${1:-/tmp/bar-headless-$(id -u)}"
SCRIPT="${2:-$PWD/tests/test_t2_transporter_capacity.lua}"

mkdir -p   "$WORKDIR"
rm  -rf    "$WORKDIR/LuaUI/Config"          # keep UI cache from polluting results

# ---------- 2. locate the engine ----------
if SPRING_BIN="$(command -v spring-headless 2>/dev/null)"; then
    :  # found on PATH
elif [[ -n "${ENGINE_DESTINATION:-}" && -x "$ENGINE_DESTINATION/spring-headless" ]]; then
    SPRING_BIN="$ENGINE_DESTINATION/spring-headless"
elif [[ -x "./spring-headless" ]]; then
    SPRING_BIN="./spring-headless"
else
    echo "❌  spring-headless binary not found." >&2
    echo "    Checked \$PATH, \$ENGINE_DESTINATION, and the cwd." >&2
    exit 1
fi

# ---------- 3. run the test ----------
echo "▶  Running $SCRIPT via $SPRING_BIN …"
"$SPRING_BIN" --isolation --write-dir "$WORKDIR" "$SCRIPT"
