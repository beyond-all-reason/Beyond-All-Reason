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

## Attack and Set Target regressions

The normal CI suite includes the twelve tests in `luaui/Tests/target_lists`.
They exercise target order and Stop, append/prepend, ground-attack boundaries,
queue skipping, the Stop the Command Queue Manager issues when the last listed
target is skipped, independent Attack and Set Target state, pending Attack
weapon behavior, and command packet boundaries. Team 0 is the issuing team and team 1
is the enemy (the standard one-team startscript supplies Gaia as team 1).
A missing enemy team fails setup instead of silently skipping the tests.
Wait/resume, manual Attack precedence, short-list scan costs and both widgets'
packet delivery are also covered by the Busted suite (`lx --lua-version 5.1 test`).

For a focused engine run, replace `runtestsheadless` in a copy of the startscript
with `runtestsheadless target_lists`. Use a disposable data/write directory with
`games/BAR.sdd` pointing at the checkout, the required map under `maps`, and a
`testlog` directory. Run the engine with `--isolation --write-dir` pointing there.
The result is `testlog/results.json`; check its failures as well as the engine
exit status. Add `Name=TestRunner;` under `[PLAYER0]` to avoid the extra spectator
connection on engines that no longer infer that name.

The larger combat and memory measurements remain in `luaui/Scenarios/stresstest`:
`attack_shared_set_target_combat`, `set_target_ground_combat_scaling`, and
`set_target_shared_scaling`. Run them explicitly with `/runscenario <name>`.
They are benchmarks, not part of the CI integration result. The other target-list
scenarios there cover extended mutations, capture/alliance changes and sensor loss.

For performance comparisons, use the same engine, map, placements and orders
on the base and PR commits. Report the two game SHAs and the engine version;
measure command-issue time, simulation frame time and peak synced-Lua memory.
Include both a short target list and a large selection. Historical recordings
from earlier revisions do not establish the behavior or timings of the current PR.
