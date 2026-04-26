#!/usr/bin/env bash
# Shared launcher. Usage: ./_run.sh <command-name>
# Runs repo_tools/commands.ps1 via pwsh, then shows a success/failure message.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pwsh -NoProfile -File "$here/commands.ps1" "$1"
rc=$?
echo
if [ "$rc" -eq 0 ]; then
    echo " Done!"
else
    echo " Something went wrong (exit code $rc). Please share the output above with the team."
fi
echo
read -r -p "Press Enter to continue..." _
exit $rc
