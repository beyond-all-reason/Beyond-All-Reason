# Experimental portal worlds

Optional BAR mode for independent duels on regions of one composed map. Set
`portal_worlds=portals` on a map with `mapconfig/portal_worlds.lua`. The default
`off` mode retains ordinary gameplay. Requires a Recoil build providing
`mapRegionViews`, `sensorRegions` and `mapDamageRegions` (engine draft
[PR #3571](https://github.com/beyond-all-reason/RecoilEngine/pull/3571)).

A commander's death opens a connection with one portal at the death position and
its partner near the destination's centre. Ordinary BAR commander elimination
still applies. The connection graph, region count, coordinates, resources, starts
and visual profiles belong to the map metadata. The example uses four real 8×8
maps, arranged in a ring: Living Lands 4.1, Barren 2, FrozenPlanetV3 and Calayo2.
512-elmo **cubicle barriers** and outer SMF page padding produce an 18×18 archive.

## Playing locally

The portable launcher is `tools/portal_worlds/play_portals.py`. It prints the run,
console log, engine log and screenshot locations. `--play` opens a human-vs-BARb
match with passive viewing unavailable until a connection opens; `--watch` opens
an AI match. Default automated runs use SDL offscreen, 15 FPS and two engine
workers. `--headless` selects the native headless executable for unattended
simulation without drawing.

```sh
python3 tools/portal_worlds/play_portals.py \
  --engine-dir /path/RecoilEngine/build-amd64-linux/install \
  --map-dir /path/content/maps/portal_worlds_v3.sdd \
  --workspace /path/bar-portal-data --play
```

`--game-dir` defaults to this checkout. `--side Cortex` selects Cortex;
`--side Legion` selects and enables the experimental Legion faction.
`--normal --original-map-dir /path/content/living-source` launches ordinary BAR
on the first original source map. The graphical launcher targets Linux; offscreen
tests require `cc` and the engine's offscreen cursor fallback.

The map fetcher, pinned original-archive manifest, SMF packer and map helper
sources are included in the [ZK portal draft](https://github.com/ZeroK-RTS/Zero-K/pull/5974)
under `tools/portal_worlds/`. That packer uses the ZK checkout's authored map
metadata to generate the game-neutral `portal_worlds.lua` contract consumed here.
It preserves source terrain, diffuse tiles/mipmaps and attribution. Map media,
engine binaries and generated archives are outside this game commit. Keep all
launcher workspaces outside the game checkout as well.

## Orders and views

Right-click a portal, or issue a move/fight/attack destination in a connected map.
Proximity alone never triggers travel. Portal attack/guard/repair/reclaim/capture/
load interactions become `GameCMD.PORTAL_TRAVEL`. Arrival removes stale source
waypoints and approach orders. Shift queues, cancellation and inserted waypoints
use command tags. Transports bring their native cargo. Carrier-owned independent
drones preserve their offsets, docked membership and construction state through
the carrier gadget's transit-member provider.

The right-side selector and N cycling appear only after opening. Only reachable
maps can be selected, and each keeps its camera. Native world rendering, cameras,
minimap input/icons, selection overlays and sensor range rings follow the active
region. Metal-spot rings and yield billboards also follow the region, including
clipping at its edges in both above-water and underwater drawing passes.
Materials/DNTS, sun, atmosphere and water presentation switch with it.
Portal mode currently uses BAR's classic native minimap; the separate PIP minimap
renderer is disabled in this mode. Global map-edge mirrors are disabled too.

Target acquisition, projectile origin/crossings/interception, explosions, shields
and unit/wreck damage stay within their source region. Damage is rejected before
other gadget callbacks. Repeating area damage retains its physical origin after
its owner travels; shield coverage queries also filter regions. Native sensors
and craters use the engine region APIs. Terrain movement speeds and build masks
provide the remaining cubicle barrier components.

## Verification and limits

Opt-in fixtures run with `--test four`, `weapons`, `barriers`, `baseline` or `ai`.
Use NullAI for deterministic fixtures (the default for `--test`); `--test ai --ai
BARb --frames 6100` exercises ordinary bot economies and a controlled commander
loss. Lua geometry checks run with `lua5.1 tests/portal_worlds.lua`.
`tools/portal_worlds/verify_runs.py /path/workspace/runs/RUN ...` validates complete
assertion counts and exit status, rather than successful startup alone.

Coverage includes physical start membership, commander-loss opening, locked views,
real player right-click travel, physical destination coordinates for ground/air
units, cargo and carrier drones, a multi-selection walking from outside the
entrance radius after a UI right-click, stale queues, native nuke/anti-nuke
launches, launch provenance after owner travel,
GPU metal-spot drawing with active/foreign/ordinary bounds in both water passes,
edge craters/building footprints, timed area damage and local/foreign shield
queries. Graphical fixtures capture all four materials and minimaps. The barrier
fixture flattens terrain only for that test, to distinguish terrain slopes from
movement masks.

The separate `ai_match` observer runs an autonomous AI match: it records native
commander deaths, death-site portal openings, physical map transitions and
`GameOver` winners. It never spawns units, kills commanders or issues unit orders.
For example:

```sh
python3 tools/portal_worlds/play_portals.py \
  --engine-dir /path/RecoilEngine/build-amd64-linux/install \
  --map-dir /path/content/maps/portal_worlds_v3.sdd \
  --workspace /path/bar-portal-data --headless --test ai_match --ai BARb \
  --frames 108000 --speed 20 --seconds 1200
python3 tools/portal_worlds/verify_ai_match.py /path/bar-portal-data/runs/RUN
```

The frame limit is simulation time; `--seconds` is the wall-clock limit. Reaching
either limit is not a victory. The verifier requires a single native winner,
physical travel by that winner and a foreign-map commander kill for a completed
portal campaign. `--normal` runs a control match on the original source map.
Optional `--ai-profile` and `--opponent-profile` select stock BARb profiles for
team 0 and the remaining teams; omitted profiles retain the AI defaults.
`--ai-seed` sets a fixed BARb random seed; the command, start script and recording
are preserved in each run directory. AI fixtures select BARb by default, while
scripted mechanics fixtures retain NullAI.

To accelerate the opening duels, add `--duel-income-multiplier 10`. This gives the
first team in each region 10× metal and energy income through the native team
`IncomeMultiplier` start-script setting; its opponent keeps ordinary income.
The teams are chosen from the composition metadata. Starting stores remain the
same. The observer records the engine's actual multipliers and the verifier
checks them against the launch record. This is an explicitly resource-asymmetric
test; the observer still gives no unit orders and never forces a death or victory.
The option defaults to 1 and does not change ordinary play.

The game command router reacts to move/fight/attack orders into another region.
Unmodified BARb uses physical connectivity in `CanMoveToPos` and
`CanMobileReachAt`, so ground armies can reject foreign destinations before
issuing an order. A stock-AI run with 10× income won local duels and made 133
aircraft crossings but reached its 60-minute cap without an overall winner.

The companion native BARb portal-missions branch adds a dedicated military task.
After local hostile teams are eliminated, it finds a contested region through
open connections and dispatches mobile ground combat units. Builders,
commanders, aircraft, retreating units and player-controlled units retain their
normal tasks. Nearby known threats keep defenders from leaving. Arrival refreshes
the cached physical terrain area and hands units back to ordinary combat;
missions have a five-minute timeout. This native planner supplies the missing
orders; the game observer remains read-only. It is an initial invasion policy,
without supply-base or coordinated multi-region defence planning.

The native planner completed a four-map headless campaign at 32:44.5: team 6 won
its local duel, visited all four maps, killed three foreign commanders and reached
native `GameOver`. There were 2,198 physical crossings, including ground units.
A single-map control with this native AI also reached `GameOver`, with no portal
missions. These resource-asymmetric checks do not establish balanced AI strength
or complete coverage of every unit and map layout.

Build an isolated native AI installation from the companion source checkout:

```sh
python3 tools/portal_worlds/build_barb.py \
  --engine-source /path/RecoilEngine \
  --ai-source /path/BARb-with-portal-missions \
  --output /path/bar-portal-data/portal-ai
```

The helper builds only the Linux `BARb` target, uses two jobs/CPUs by default,
records source/library hashes, and refuses to overwrite an existing AI root.
Pass `--ai-dir /path/bar-portal-data/portal-ai` to the launcher. Without it the
portable launcher uses the engine's existing AI. `--ai-dir` affects AI loading,
not the engine executable. The companion source must be committed locally so
build provenance is exact; these changes remain separate from the engine patch.

The opt-in public GameRulesParam protocol has version 1. Region/edge identifiers
are one-based, and team identifiers retain their native values:

| Parameter | Meaning |
| --- | --- |
| `portal_ai_version` | Protocol version; absent on ordinary maps |
| `portal_regions`, `portal_edges` | Region and edge counts |
| `portal_r{r}_x0/z0/x1/z1` | Region rectangle, maximum edges exclusive |
| `portal_e{e}_a/b/open` | Connected regions and whether travel is open |
| `portal_e{e}_r{r}_x/z` | Physical mouth position for an open connection |
| `portal_team{t}_region/alive` | Original region and public elimination state |

The protocol publishes topology and elimination information, with no hidden unit
positions or targets. The native AI reads it through existing game callbacks;
ordinary maps do not enable the planner.

This is ongoing WIP pending human playtesting and review, longer multiplayer and
mixed-platform runs, large-match performance, broader optional mechanics and
full-game persistence coverage. The native invasion policy remains experimental. The earlier AI smoke run verifies
factory/unit production and a portal opening, and does not assert autonomous
portal strategy. Gravity, water height, path storage, unit limits and team economy
remain shared by one simulation.

AI assistance: OpenAI Codex adapted the game mode, UI, tooling and automated
fixtures and ran the checks. Human review/editing and manual verification remain
pending. No BAR pull request has been submitted.
