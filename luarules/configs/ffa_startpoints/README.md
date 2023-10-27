# FFA start setup gadget

This directory holds FFA start points configs intended to be consumed by the
**FFA start setup** gadget (`game_ffa_start_setup.lua`), which is responsible
for setting up start points and start boxes in FFA and TeamFFA games.

## Why

Start positions in FFA and TeamFFA are an extremely important variable, as a
huge part of the early game is trying to determine who's where and what one
should do based off that.

An annoying quirk when using start boxes is that they must be set from the lobby
and are tied to a specific team (e.g. team 1 will use start box 1), which
removes the uncertainty factor as all players know immediately where everybody
starts before the game has even launched.

When not using start boxes, players will be randomly placed at the start of the
match based on start positions defined by the map's `mapinfo.lua`. However, not
all maps properly define start positions in a way that will work for FFA games,
and some maps do not even define enough start positions to allow for all players
to spawn properly, even if the map could actually support it.

On top of that, the start positions defined from `mapinfo.lua` are a plain list,
which is not flexible enough to define multiple layouts of start positions
depending on the number of contestants (e.g. one specific layout for 5-way,
another one for 7-way).

The **FFA start setup** gadget's purpose is to address all of these issues.

## How

If using start boxes, the gadget will shuffle them at game start so as to make
sure that nobody can know where anybody else is based off the start boxes
defined in the lobby.

If not using start boxes, the gadget will try to leverage custom FFA start
points configs to position players at the start of the game in a better way than
by relying on the map's `mapinfo.lua` default start positions. To do so, it will
use, in order of priority:

- The FFA start points config provided by BAR for the current map, if available
  from this directory.
- The FFA start points config provided by the map itself, if available.

If no matching configuration can be found, or a configuration is found but no
layout is available to accommodate the number of contestants, the default map
start positions will be used as usual instead.

The FFA start points config format (see below) allows for any number of start
points and layouts of start points to be defined, thereby addressing all the
issues above since it can define dedicated layouts for all types of FFA, no
matter the number of contestants, and no matter the default map start positions.

It can even define multiple sets of layouts for the same number of contestants,
allowing for increased uncertainty between matches as rematches on the same map
with the same number of contestants might use a completely different layout.

After shuffling the start boxes and retrieving then shuffling start points if a
layout is available, the gadget removes itself and lets the game carry on as
usual. The start points loaded from the FFA start points config file are stored
in `GG` for the `game_initial_spawn.lua` gadget to use and spawn start units
where appropriate.

## Adding a config file for a new map

**FFA start setup** will try to match the base filenames from this directory
with the current map name, i.e. filenames are expected to be `{substring}.lua`,
with `{substring}` being a unique substring of the map name, and of course it
expects the file to respect a specific format defined below.

The filename substring matching is case-insensitive and space-insensitive, so
feel free to use readable filenames without need to conform to the actual map
name, and without need to include version (which allows for map updates to
happen without any change required on the FFA start points side). For example,
`Foo Bar.lua` will match any map name with a variant of `Foo Bar` somewhere:

```
Foo Bar Baz V1
foo_bar_baz_v1
BaZ FOO_bar V1
```

Alternatively, map authors can also bundle a FFA start points config by
including a `luarules/configs/ffa_startpoints.lua` file in the map archive, and
respecting the same file format below. However, if a matching config for the
current map is available both in this directory and in the map archive, the
gadget will prioritize the config provided by BAR.

## File format

The config file will be loaded via `VFS.Include` and its return value will be
retrieved by **FFA start setup**. The return value must be a table providing the
following items:

- `startPoints`: a sequence of coordinates containing all the start points of
  the map. Format: `startPoints[i] = { x = <coordX>, z = <coordZ>, }`
- `byAllyTeamCount`: a table of available start points layouts indexed by number
  of ally teams. Format: `byAllyTeamCount[i] = { {layout1}, {layout2}, ... }`,
  with each `{layoutX}` being a sequence of start point indexes mapping to
  `startPoints`.

Example:

```lua
local startPoints = {
  [1] = { x = 0, z = 0, },
  [2] = { x = 0, z = 100, },
  [3] = { x = 100, z = 100, },
  [4] = { x = 100, z = 0, },
}

local byAllyTeamCount = {
  -- 3-way layouts
  [3] = {
    { 1, 2, 3, },
    { 2, 3, 4, },
    { 1, 3, 4, },
  },

  -- 4-way layouts
  [4] = {
    { 1, 2, 3, 4, },
  },
}

return {
  startPoints = startPoints,
  byAllyTeamCount = byAllyTeamCount
}
```

## Generating config files with the in-game editor

An in-game editor companion widget **FFA start points picker**
(`dbg_ffa_startpoints_picker.lua`) is provided to generate configs in a
convenient way. The widget will only work in solo games (nothing but the player,
not even AIs) with dev mode and cheats enabled. It will not allow itself to run
in any other situation, including replays and singleplayer games where the
player is alone but there are AIs.

The in-game editor is extremely op because it uses Armada commanders. (gg.) The
general principle is to position as many commanders around the map as necessary,
each commander materializing a potential start point (typically near a bunch of
mexes). After commanders have been positioned as desired, the editor allows to
create layouts containing X number of start points, materializing a specific
start point setup for an X-way FFA. Once layouts have been finalized, the editor
then allows to export to a config file formatted as expected above. It can also
load config files for editing.

To get started, jump into a solo game (no AIs) in dev mode, and make sure the
widget is enabled via Widget Selector (F11 or `/widgetselector`). If it does not
load when you enable it, you probably need to enable cheats (`/cheats` or enable
the autocheat widget), then reload the widget. Check `infolog.txt` for more
details what is blocker the loading if needed.

### Creating a config file for a new map from scratch

- Use `Ctrl`+`A` to add a new start point (commander) at the cursor. You can
  then move the commander around and have it build nearby mexes etc. so as to
  adjust its position as precisely as you like. Repeat for all start points on
  the map.
- Use `Ctrl`+`D` to remove all currently selected start points.

Once satisfied with the start points:

- Use `A` to add a new X-way layout based on the selected start points (minimum
  3). Repeat for all desired layouts.
- Use `D` to remove the currently selected layout.
- Use `Q`/`E` to cycle layout pages if needed. By default all are shown but
  depending on your resolution and the amount of layouts, they might overflow
  at the bottom, so you can display 3- to 9-way and 10- to 16-way separately.

Note that start points can still be added or removed at this stage, however
removing any start point will also delete all existing layouts containing that
start point.

Once satisfied with the layouts:

- Use `Ctrl`+`C` to copy the config to the clipboard, and also store an
  ephemeral version. You can then use `Ctrl`+`Z` to reset to this state. This
  allows you to quickly save something you're satisfied with right now, try
  something wacky, and reset to the last known good state.
- Use `Ctrl`+`W` to save the config to a WIP file, which will be located in the
  game's directory at `data/LuaUI/dbg_ffa_<map name>-<count>.lua` (with
  `<count>` increasing on subsequent `Ctrl`+`W`). This WIP config file can be
  reloaded later via `Ctrl`+`L` (see next section).

### Loading an existing config file for editing

Use `Ctrl`+`L` to load existing config files. It will check for, in order:

- WIP config files saved previously via `Ctrl`+`W` and located in
  `data/LuaUI/dbg_ffa_<map name>-<count>.lua`. This allows you to save your work
  at any time, close BAR, and go do something else before coming back to it. If
  there are multiple matches, the last WIP config file (as denoted by `<count>`)
  will be used. (One caveat: freshly saved WIP configs are not available for
  loading during the same session as when they were created. This is a
  limitation of the VFS filesystem, use `Ctrl`+`C` / `Ctrl`+`Z` instead for this
  use case.)
- Config files provided by BAR for the current map. This allows you to edit them
  in an easy way. Note that any comments from the original file are lost, so in
  this case you'll likely want to do a manual merge of the differences between
  your new version and the old one, rather than just an overwrite.

## Testing config files

A companion Python utility `start_scripts_generator.py` is provided to generate
start scripts in order to test config files in a convenient way.

The configurations near the top of the generator dictate what start scripts will
be generated:

```python
CONFIGURATIONS = {
    'Throne_V8': [3, 5, 7, 10, 12, 15, 16],
}
```

Simply add the desired map and a list containing the configurations you want to
test, e.g. on the above we want to test `Throne_V8` in 3-way, 5-way, etc. and
then run the script with Python, which will generate configuration files in
`luarules/configs/ffa_startpoints/start_scripts`.

After making sure the FFA start points config you want to test has been properly
placed in this directory so that it gets picked up by the **FFA start setup**
gadget, you can then use the start scripts to immediately launch a FFA game on
that map with that number of contestants, without going through the launcher, in
order to quickly test all layouts from the config file.

For example, from PowerShell on my machine (need to use absolute path otherwise
the engine is not happy):

```powershell
& 'D:\Games\Beyond-All-Reason\data\engine\105.1.1-1821-gaca6f20 bar\spring.exe' --isolation `
  --write-dir 'D:\Games\Beyond-All-Reason\data' `
  'D:\Games\Beyond-All-Reason\data\games\BAR.sdd\luarules\configs\ffa_startpoints\start_scripts\Throne_V8_FFA_7-way.txt'
```

Note that on top of generating a start script for each requested configuration,
a `Solo` start script will also be generated, which can be handy to quickly use
the in-game editor on any map.
