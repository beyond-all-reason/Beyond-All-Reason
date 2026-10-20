# Dots recordings

Record an AI match from its spectator client with the portal launcher’s
`--record --headless` or `--record --watch` options. `--watch` opens the actual
game window; headless recording needs no display or GPU. `--play` is ordinary
human gameplay and does not enable this all-team recorder. Recording is off by
default. The launcher prints its run directory; the data is written under
`RUN/write/recordings/`. A game-over or configured frame limit closes the file.
An interrupted recording lacks a footer and is rejected.

Prepare playback from the game’s `tools/portal_worlds` directory:

```sh
python3 dots.py pack /path/RUN/write/recordings/portal-dots-TIMESTAMP.jsonl \
  --run /path/RUN --out /path/match.jsonl.gz
python3 dots.py bundle /path/match.jsonl.gz --out /path/match.html \
  --map-dir /path/portal_worlds_v3.sdd
python3 dots.py review /path/match.jsonl.gz
```

Open `match.html` in a current Chrome, Chromium, Firefox or Safari browser. It
contains the recording and player, works offline and needs no server or engine.
The shareable copy uses one-second samples and rounds displayed positions/HP
to 0.1 units. It records those display changes and the original data hash in its
header and a receipt. The full half-second recording remains unchanged for
analysis; use `--sample-frames 15` to keep its sample cadence.
Share that single file for playback; `.jsonl.gz` plus `dots/viewer.html` is an
alternative. The optional map background uses Pillow and the composed map’s
original minimap; it is presentation only. Preserve the map authors’ attribution
with any distributed recording/background.

Play/pause, seek, change playback speed, inspect units, follow recent paths and
orders, or switch between all worlds and one enlarged world. Each world can be
panned/zoomed independently. Portal rings use matching connection numbers.
Commander losses, portal openings and first arrivals have timeline bookmarks.
Unit IDs are paired with birth frames, and interpolation never crosses a world
change or a reused ID. Building squares, mobile dots, team colours, health,
construction progress and current engine orders come from recorded state.
A factory’s current engine command describes its produced-unit default order;
this recorder does not capture the production queue. Shots are native projectile positions and damage-event markers. They do not
recreate particles, meshes, terrain occlusion, weapon timing between samples,
player fog of war or the AI’s knowledge. The player sends no game commands.

`portal-dots` v1 is JSON Lines: a header declares definitions, regions, teams,
FPS and compact array columns; samples hold unit/projectile positions, current
orders, resources and portal mouths; exact-frame events hold shots, damage,
deaths, observed region changes and portal openings. A footer reconciles the
sample/event counts. Unit samples are half a simulation second apart. Numeric
`false` slots mean an absent command parameter, not a zero coordinate.

The recorder only reads simulation state, registers projectile observations and
sends data to the unsynced file writer. It consumes no RNG and issues no unit
orders, movement, damage, resource grants or victory. Only a full-view spectator
writes the all-team stream. Native AI does not read it. Scripted fixtures must
be identified as fixtures rather than represented as autonomous AI matches.

The review command checks the schema/footer and lists foreign projectile/hit
observations, orders into cubicle barriers, units outside regions, prolonged
edge dwell and rapid return trips. Edge dwell and return trips are candidates
for inspection: they can be legitimate defence or retreat. A projectile’s launch
region is recorded separately from its owner’s current region; an owner can
teleport after firing. Position-only damage candidates cannot establish a
foreign hit without examining that context. Sampling misses some short-lived
arrivals; transit counts are lower bounds. These checks complement real weapon,
barrier and gameplay fixtures rather than proving every weapon works.

Existing launcher replays can also be exported:

```sh
python3 dots.py export /path/RUN --engine-dir /path/engine \
  --out /path/replayed-match.jsonl.gz
```

Export requires the exact engine version and matching gameplay source. It copies
editable source into a disposable observer overlay, shares immutable media,
omits native AI libraries and replays the recorded commands headlessly. The
identified overlay changes the game archive checksum. Lua errors, desyncs,
unfinished demos and missing recording footers reject the capture. Native AI
matches can have replay limitations; a rejected replay is never a demonstration.
Prefer recording the original live match. Source/replay hashes, command lines,
capture limits and review results remain beside accepted exports. Loose exports
without a frozen runtime/reference trace are labelled accordingly.

Run `python3 test_dots.py` for the schema and spatial-classification regressions.
Review the actual player at combat, portal opening, transit and final victory
before sharing a match. OpenAI Codex assisted with this recorder, player, tools
and automated tests; human review and playtesting remain pending.
