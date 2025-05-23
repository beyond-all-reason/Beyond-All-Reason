#!/bin/bash
set -e
if command -v luajit >/dev/null 2>&1; then
    LUA=luajit
elif command -v lua >/dev/null 2>&1; then
    LUA=lua
else
    echo "Lua interpreter not found" >&2
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "Usage: $0 <testfile.lua>" >&2
    exit 1
fi

"$LUA" "$1"
