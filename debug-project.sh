#!/usr/bin/env bash
echo "Shows debug information about the lux project configuration."
echo
exec "$(dirname "$0")/repo_tools/_run.sh" debug-project
