#!/usr/bin/env bash
echo "This will download and install the Lua tools needed to work"
echo "with this repository. It may take a minute on first run."
echo
exec "$(dirname "$0")/repo_tools/_run.sh" install
