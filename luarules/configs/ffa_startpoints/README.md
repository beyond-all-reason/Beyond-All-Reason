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
