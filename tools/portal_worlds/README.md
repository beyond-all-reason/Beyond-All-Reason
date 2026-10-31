# BAR portal launcher

See [setup and mechanics](../../docs/portal-worlds.md). The launcher consumes a
composed `.sdd` map and this checkout. Downloads and generated media remain in a
separate workspace. Use `--play` for an interactive match; automated runs stay
offscreen. The small `limit_swap.c` helper is compiled into the workspace for
15 FPS offscreen rendering and is unused for visible play.

```sh
python3 play_portals.py --help
python3 verify_runs.py /path/workspace/runs/portal-test
```

AI assistance: OpenAI Codex prepared these prototype tools and their checks.

Automated BAR checks default to the graphical engine with SDL offscreen.
`--headless` uses the native headless executable. The `ai_match` observer and
`verify_ai_match.py` distinguish an autonomous native victory from a timed run;
see the gameplay document for a complete invocation.

Use `--duel-income-multiplier 10` to give one team in each map 10× income for
faster opening duels. Defaults to ordinary income; the observer and verifier
record and check the actual native team multipliers.

Native ground invasion needs the companion BARb portal-missions source. Use
`build_barb.py` to compile it into a new isolated AI root, then pass `--ai-dir`
to `play_portals.py`. The helper preserves the existing engine/AI installation;
it builds only the native AI target and records its exact source and library
hashes. See the gameplay document for the protocol and full commands.

The map fetcher/packer, pinned `portal_maps.json`, generic map helper sources and
attributed `map-metadata` overrides are included here too. Install `requirements.txt`,
set `BAR_PORTAL_WORKSPACE` outside this checkout, run `fetch_portal_maps.py`, then
`build_portal_worlds.py --engine-dir /path/engine` and `verify_four_worlds.py`.
Repacking needs Python/Pillow, Lua 5.1 and 7z; using an already composed map does not.

`--record` writes dots for spectator AI matches. See [dots playback](dots/README.md)
for validation, compact recording files, offline sharing and review limits.

For aircraft and projectile edge rendering, use an engine exposing `Engine.FeatureSupport.objectDrawBounds`. The game keeps the terrain crop fixed and gives flying objects a margin of at most one sixteenth of the region's shorter side, limited to half the separating distance from any neighbor. The supplied four-map composition gets a 256-elmo margin inside its cubicle barriers. Margins cannot overlap, including diagonal neighbors. Aircraft are contained at that outer edge and projectiles are removed before crossing it; ground pathfinding and building boundaries stay at the terrain edge. Older preview engines retain the strict terrain-edge behavior.

The opt-in `--test edges --speed 0.4 --frames 900` fixture checks survival inside the margin and containment outside it, then records native aircraft and artillery projectiles crossing the terrain edge. Flight is scripted with MoveCtrl to make the rendering example repeatable; it is not an AI bombing-run test. Normal portal isolation stays enabled. Screenshots go to the run's `write/screenshots/edge-*.png`. Use the offscreen GPU launcher (plus `--human` for Zero-K), and allow at least 180 seconds. The fixture requires the newer engine API. Geometry and compatibility checks can also run without the engine: `lua5.1 tools/portal_worlds/test_object_bounds.lua` from the game root.
