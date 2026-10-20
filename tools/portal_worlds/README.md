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
