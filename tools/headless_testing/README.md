# Headless automated integration testing using docker compose

If running from this directory, run `docker compose up`

If running from the root directory of this repository, run `docker compose -f tools/headless_testing/docker-compose.yml up`

## Running without docker, against an installed BAR client

If you already have BAR installed, its launcher has downloaded engines and maps that can be reused directly. This
skips the image build and runs in well under a minute.

Requires this repository to be the game at `$BAR_DATA/games/BAR.sdd` and the map `Supreme Isthmus v2.1` to be
downloaded (the startscript's map — play it once, or fetch it with `pr-downloader --download-map`).

```sh
# Data directory of the installed client. Flatpak shown; native installs use the launcher's data dir.
BAR_DATA=~/.var/app/info.beyondallreason.bar/data

mkdir -p "$BAR_DATA/testlog"   # results are dropped here; without it nothing is written
"$BAR_DATA/engine/<engine-version>/spring-headless" \
    --isolation --write-dir "$BAR_DATA" \
    "$BAR_DATA/games/BAR.sdd/tools/headless_testing/startscript.txt"
```

The engine quits by itself when the run finishes. Results land in `$BAR_DATA/testlog/results.json`, and the
per-test `PASS` / `FAIL` / `SKIP` lines are in the console output and `$BAR_DATA/infolog.txt`.

Do not use `start.sh` for this: it deletes `LuaUI/Config` in the write directory, which is disposable in the
container but is your real configuration in an installed client.

## test file locations
Some tests exist in
 - [common/testing/infologtest.lua](../../common/testing/infologtest.lua)
 - [luaui/Tests/cmd_blueprint/test_cmd_blueprint_filter.lua](../../luaui/Tests/cmd_blueprint/test_cmd_blueprint_filter.lua)
 - [luaui/Tests/cmd_stop_selfd/test_cmd_stop_selfd.lua](../../luaui/Tests/cmd_stop_selfd/test_cmd_stop_selfd.lua)

## CICD
Note: these tests are run as part of GitHub Actions on every PR.
