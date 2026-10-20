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
an AI match. Automated runs use SDL offscreen, 15 FPS and two engine workers.

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
entrance radius after a UI right-click, stale queues, native nuke/anti-nuke launches, launch provenance after owner travel,
GPU metal-spot drawing with active/foreign/ordinary bounds in both water passes,
edge craters/building footprints, timed area damage and local/foreign shield
queries. Graphical fixtures capture all four materials and minimaps. The barrier
fixture flattens terrain only for that test, to distinguish terrain slopes from
movement masks.

This is ongoing WIP pending human playtesting and review, longer multiplayer and
mixed-platform runs, large-match performance, broader optional mechanics and
full-game persistence coverage. BARb plays its ordinary local economy; deciding
when and how to invade through portals needs AI work. The AI smoke run verifies
factory/unit production and a portal opening, and does not assert autonomous
portal strategy. Gravity, water height, path storage, unit limits and team economy
remain shared by one simulation.

AI assistance: OpenAI Codex adapted the game mode, UI, tooling and automated
fixtures and ran the checks. Human review/editing and manual verification remain
pending. No BAR pull request has been submitted.
