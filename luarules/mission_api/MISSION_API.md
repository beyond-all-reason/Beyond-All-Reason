# Mission API

Missions are Lua files placed in `singleplayer/`. The engine loads the file and reads the table it returns.

---

## Table of contents

- [Mission file structure](#mission-file-structure)
- [Triggers](#triggers)
  - [Settings](#settings-all-optional)
  - [Time](#time)
    - [TimeElapsed](#timeelapsed)
  - [Units](#units)
    - [UnitExists](#unitexists)
    - [UnitNotExists](#unitnotexists)
    - [UnitKilled](#unitkilled)
    - [UnitCaptured](#unitcaptured)
    - [UnitResurrected](#unitresurrected)
    - [UnitEnteredLocation](#unitenteredlocation)
    - [UnitLeftLocation](#unitleftlocation)
    - [UnitDwellLocation](#unitdwelllocation)
    - [UnitSpotted / UnitUnspotted](#unitspotted--unitunspotted)
    - [ConstructionStarted / ConstructionFinished](#constructionstarted--constructionfinished)
  - [Features](#features)
    - [FeatureCreated](#featurecreated)
    - [FeatureReclaimed](#featurereclaimed)
    - [FeatureDestroyed](#featuredestroyed)
  - [Resources](#resources)
    - [ResourceStored](#resourcestored)
    - [ResourceIncome / ResourceExpense / ResourcePull](#resourceincome--resourceexpense--resourcepull)
  - [Statistics](#statistics)
    - [TotalUnitsLost / TotalUnitsBuilt / TotalUnitsKilled / TotalUnitsCaptured](#totalunitslost--totalunitsbuilt--totalunitskilled--totalunitscaptured)
  - [Team](#team)
    - [TeamDestroyed](#teamdestroyed)
- [Actions](#actions)
  - [Trigger control](#trigger-control)
    - [EnableTrigger / DisableTrigger](#enabletrigger--disabletrigger)
  - [Stages & Objectives](#stages--objectives)
    - [ChangeStage](#changestage)
    - [UpdateObjective](#updateobjective)
  - [Orders](#orders)
    - [IssueOrders](#issueorders)
  - [Units](#units-1)
    - [SpawnUnits](#spawnunits)
    - [DespawnUnits](#despawnunits)
    - [TransferUnits](#transferunits)
    - [NameUnits](#nameunits)
    - [UnnameUnits](#unnameunits)
  - [Features](#features-1)
    - [CreateFeature](#createfeature)
    - [DestroyFeature](#destroyfeature)
  - [Loadout (dynamic)](#loadout-dynamic)
    - [SpawnLoadout](#spawnloadout)
  - [SFX](#sfx)
    - [SpawnExplosion](#spawnexplosion)
  - [Media](#media)
    - [PlaySound](#playsound)
    - [SendMessage](#sendmessage)
    - [AddMarker](#addmarker)
    - [EraseMarker](#erasemarker)
    - [DrawLines](#drawlines)
    - [ClearAllMarkers](#clearallmarkers)
  - [Win conditions](#win-conditions)
    - [Victory / Defeat](#victory--defeat)
  - [Other](#other)
    - [AddResources](#addresources)
    - [Custom](#custom)
- [Stages and Objectives](#stages-and-objectives)
- [Loadouts](#loadouts)
- [Named units and features](#named-units-and-features)
- [Facing values](#facing-values)
- [Area values](#area-values)
- [Minimal complete example](#minimal-complete-example)

---

## Mission file structure

```lua
local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes  = GG['MissionAPI'].ActionTypes

return {
    -- Optional. Defaults to "initialStage".
    InitialStage   = 'stage1',

    -- Optional. Shown in the mission UI.
    Stages         = { ... },
    Objectives     = { ... },

    -- Required.
    Triggers       = { ... },
    Actions        = { ... },

    -- Optional. Spawned before the first game frame.
    UnitLoadout    = { ... },
    FeatureLoadout = { ... },
}
```

---

## Triggers

A trigger fires when its condition is met, then runs its list of actions.

```lua
myTrigger = {
    type       = triggerTypes.TimeElapsed,  -- required
    parameters = { gameFrame = 150 },       -- required (type-dependent)
    settings   = { ... },                   -- optional
    actions    = { 'myAction' },            -- required; at least one action ID
},
```

### Settings (all optional)

| Field | Type | Default | Description |
|---|---|---|---|
| `active` | boolean | `true` | If `false`, the trigger is disabled and will not fire |
| `repeating` | boolean | `false` | If `true`, the trigger may fire more than once |
| `maxRepeats` | number | none | Maximum number of extra fires after the first (requires `repeating = true`) |
| `prerequisites` | table | `{}` | Array of trigger IDs that must have fired before this one can fire |
| `stages` | table | none | Array of stage IDs; the trigger only fires while the mission is in one of these stages |
| `difficulties` | table | none | Map of difficulty levels where the trigger is active |

```lua
settings = {
    active       = false,              -- start disabled; enable with EnableTrigger action
    repeating    = true,
    maxRepeats   = 3,                  -- fires at most 4 times total
    prerequisites = { 'waveDone' },
    stages       = { 'phase2', 'phase3' },
},
```

---

### Trigger types

---

### Time

#### TimeElapsed

Fires at a specific game frame. Optionally repeats every `interval` frames.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `gameFrame` | yes | number | Frame at which to fire (30 frames ≈ 1 second) |
| `interval` | no | number | If `repeating = true`, fires every `interval` frames after `gameFrame` |

```lua
type       = triggerTypes.TimeElapsed,
parameters = { gameFrame = 900, interval = 300 },   -- fire at frame 900, then every 300 frames
settings   = { repeating = true },
```

---

### Units

#### UnitExists

Fires when a unit of the given type is created and the count reaches `quantity`.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `unitDefName` | yes | string | Unit definition name |
| `teamID` | no | number | Restrict to a specific team |
| `quantity` | no | number | Minimum count required (default: 1) |

```lua
type       = triggerTypes.UnitExists,
parameters = { unitDefName = 'armcom', teamID = 0, quantity = 2 },
```

---

#### UnitNotExists

Fires when a named unit, or any unit of a given type/team, is removed (killed, captured, etc.).

| Parameter | Required | Type | Description |
|---|---|---|---|
| `unitName` | no | string | Tracked unit name |
| `unitDefName` | no | string | Unit definition name |
| `teamID` | no | number | Restrict to a specific team |

```lua
type       = triggerTypes.UnitNotExists,
parameters = { unitName = 'bossTank' },
```

---

#### UnitKilled

Fires when a named unit, or a unit of a given type/team, is destroyed.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `unitName` | no | string | Tracked unit name |
| `unitDefName` | no | string | Unit definition name |
| `teamID` | no | number | Restrict to a specific team |

```lua
type       = triggerTypes.UnitKilled,
parameters = { unitName = 'escort', teamID = 0 },
```

---

#### UnitCaptured

Fires when a unit is captured.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `unitName` | no | string | Tracked unit name |
| `unitDefName` | no | string | Unit definition name |
| `oldTeamID` | no | number | Team that lost the unit |
| `newTeamID` | no | number | Team that gained the unit |

```lua
type       = triggerTypes.UnitCaptured,
parameters = { unitDefName = 'armwin', newTeamID = 0 },
```

---

#### UnitResurrected

Fires when a unit is resurrected from a wreck.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `unitDefName` | no | string | Unit definition name of the resurrected unit |
| `teamID` | no | number | Team performing the resurrection |

```lua
type       = triggerTypes.UnitResurrected,
parameters = { unitDefName = 'armllt', teamID = 0 },
```

---

#### UnitEnteredLocation

Fires each time a matching unit enters the area. Checked every 15 frames.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `area` | yes | Area | Rectangle `{x1,z1,x2,z2}` or circle `{x,z,radius}` |
| `unitName` | no | string | Restrict to a tracked unit name |
| `teamID` | no | number | Restrict to a specific team |
| `unitDefName` | no | string | Restrict to a unit type |

```lua
type       = triggerTypes.UnitEnteredLocation,
parameters = { area = { x = 2000, z = 2000, radius = 300 }, teamID = 0 },
```

---

#### UnitLeftLocation

Fires each time a matching unit leaves the area. Checked every 15 frames.

Parameters: same as `UnitEnteredLocation`.

```lua
type       = triggerTypes.UnitLeftLocation,
parameters = { area = { x1 = 1000, z1 = 1000, x2 = 1500, z2 = 1500 }, unitName = 'convoy' },
```

---

#### UnitDwellLocation

Fires when a matching unit has remained inside the area continuously for at least `duration` frames.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `area` | yes | Area | Rectangle or circle |
| `duration` | yes | number | Minimum continuous frames inside the area |
| `unitName` | no | string | Tracked unit name |
| `teamID` | no | number | Restrict to a specific team |
| `unitDefName` | no | string | Restrict to a unit type |

```lua
type       = triggerTypes.UnitDwellLocation,
parameters = { area = { x = 3000, z = 3000, radius = 200 }, duration = 150 },
```

---

#### UnitSpotted / UnitUnspotted

Fires when a matching unit enters or leaves the line-of-sight of an ally team.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `unitName` | no | string | Tracked unit name |
| `teamID` | no | number | Team that owns the unit |
| `allyTeamID` | no | number | Ally team doing the spotting |
| `unitDefName` | no | string | Restrict to a unit type |

```lua
type       = triggerTypes.UnitSpotted,
parameters = { unitName = 'stealth', allyTeamID = 0 },
```

---

#### ConstructionStarted / ConstructionFinished

Fires when construction of a unit begins or completes.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `teamID` | no | number | Team building the unit |
| `unitDefName` | no | string | Unit definition name |
| `unitName` | no | string | Tracked unit name (ConstructionFinished only) |

```lua
type       = triggerTypes.ConstructionFinished,
parameters = { unitDefName = 'armsolar', teamID = 0 },
```

---

### Features

#### FeatureCreated

Fires when a feature is created.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `featureDefName` | no | string | Feature definition name |
| `area` | no | Area | Restrict to a location |

```lua
type       = triggerTypes.FeatureCreated,
parameters = { featureDefName = 'armcom_dead' },
```

---

#### FeatureReclaimed

Fires when a feature is fully reclaimed.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `featureName` | no | string | Tracked feature name |
| `featureDefName` | no | string | Feature definition name |
| `teamID` | no | number | Team doing the reclaiming |
| `area` | no | Area | Restrict to a location |

```lua
type       = triggerTypes.FeatureReclaimed,
parameters = { featureName = 'crate', teamID = 0 },
```

---

#### FeatureDestroyed

Fires when a feature is destroyed (not reclaimed).

| Parameter | Required | Type | Description |
|---|---|---|---|
| `featureName` | no | string | Tracked feature name |
| `featureDefName` | no | string | Feature definition name |
| `allyTeamID` | no | number | Ally team of the attacker |
| `area` | no | Area | Restrict to a location |

```lua
type       = triggerTypes.FeatureDestroyed,
parameters = { featureName = 'bridge' },
```

---

### Resources

#### ResourceStored

Fires when a team's stored resources are at or above a threshold. Checked every 15 frames.
At least one of `metal` or `energy` is required.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `teamID` | yes | number | Team to check |
| `metal` | no | number | Minimum stored metal |
| `energy` | no | number | Minimum stored energy |

```lua
type       = triggerTypes.ResourceStored,
parameters = { teamID = 0, metal = 1000 },
```

---

#### ResourceIncome / ResourceExpense / ResourcePull

Fire when a team's income, expense, or pull is at or above a threshold.
Use `stableFrames` to avoid false positives from momentary spikes.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `teamID` | yes | number | Team to check |
| `metal` | no | number | Minimum value |
| `energy` | no | number | Minimum value |
| `stableFrames` | no | number | Condition must hold for this many consecutive frames |

```lua
type       = triggerTypes.ResourceIncome,
parameters = { teamID = 0, metal = 10, stableFrames = 150 },
```

---

### Statistics

#### TotalUnitsLost / TotalUnitsBuilt / TotalUnitsKilled / TotalUnitsCaptured

Fires when a team's running total reaches a threshold. These are cumulative lifetime counters.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `teamID` | yes | number | Team to check |
| `quantity` | yes | number | Cumulative count to reach |

> **Note:** `TotalUnitsBuilt` does not count units spawned by the mission API or units present at frame 0.

```lua
type       = triggerTypes.TotalUnitsBuilt,
parameters = { teamID = 0, quantity = 10 },
```

---

### Team

#### TeamDestroyed

Fires when a team is eliminated.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `teamID` | yes | number | Team that must be destroyed |

```lua
type       = triggerTypes.TeamDestroyed,
parameters = { teamID = 1 },
```

---

## Actions

An action is executed when a trigger fires.

```lua
myAction = {
    type       = actionTypes.SendMessage,   -- required
    parameters = { message = "Hello!" },    -- required (type-dependent)
},
```

---

### Trigger control

#### EnableTrigger / DisableTrigger

Activate or deactivate a trigger by its ID.

| Parameter | Required | Type |
|---|---|---|
| `triggerID` | yes | string |

```lua
{ type = actionTypes.EnableTrigger,  parameters = { triggerID = 'wave2' } },
{ type = actionTypes.DisableTrigger, parameters = { triggerID = 'wave1' } },
```

---

### Stages & Objectives

#### ChangeStage

Switch the active mission stage.

| Parameter | Required | Type |
|---|---|---|
| `stageID` | yes | string |

```lua
{ type = actionTypes.ChangeStage, parameters = { stageID = 'phase2' } },
```

#### UpdateObjective

Update the text, completion state, or progress of an objective.
At least one of `completed`, `text`, `unitName`, or `featureName` is required.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `objectiveID` | yes | string | Objective to update |
| `completed` | no | boolean | Mark as complete or incomplete |
| `text` | no | string | Replace the display text |
| `unitName` | no | string | Derive progress from the count of tracked units with this name |
| `featureName` | no | string | Derive progress from tracked features (not yet implemented) |

```lua
-- Mark done:
{ type = actionTypes.UpdateObjective, parameters = { objectiveID = 'captureBase', completed = true } },

-- Progress from unit count:
{ type = actionTypes.UpdateObjective, parameters = { objectiveID = 'buildTanks', unitName = 'tanks' } },
```

---

### Orders

#### IssueOrders

Send a list of orders to all units tracked under a name.

| Parameter | Required | Type |
|---|---|---|
| `unitName` | yes | string |
| `orders` | yes | Orders |

Each order is `{ commandID, parameters, options }`:
- `commandID` – a `CMD.*` constant, or a `unitDefName` string for a build order.
- `parameters` – an array of numbers: `{x, y, z}` for move/attack, `{x, y, z, radius}` for area commands, or a single number for state commands. For commands that target a unit (see below), `parameters` may instead be a tracked unit **name** (string).
- `options` – optional array of strings: `'shift'`, `'alt'`, `'ctrl'`, `'right'`, `'meta'`.

**Using a unit name as target**

The following commands accept a tracked unit name in place of coordinates:

`CMD.GUARD`, `CMD.REPAIR`, `CMD.CAPTURE`, `CMD.ATTACK`, `CMD.LOAD_UNITS`, `CMD.RECLAIM`

When a name is used, the order is duplicated for each unit tracked under that name, with `'shift'` automatically appended to the options of all but the first, so the issuing units act on all targets in sequence.

```lua
{
    type = actionTypes.IssueOrders,
    parameters = {
        unitName = 'tanks',
        orders = {
            -- coordinate-based orders:
            { CMD.MOVE,       { 3000, 0, 4000 } },
            { CMD.ATTACK,     { 3200, 0, 4100, 150 }, { 'shift' } },
            { CMD.FIRE_STATE, CMD.FIRESTATE_HOLDFIRE },
            { 'armsolar',     { 2800, 0, 3800, 2 }, { 'shift' } }, -- build order

            -- unit-name-based orders (targets all units named 'enemies' in sequence):
            { CMD.ATTACK,  'enemies', { 'shift' } },
            { CMD.CAPTURE, 'prize' },
            { CMD.GUARD,   'vip' },
        },
    },
},
```

---

### Units

#### SpawnUnits

Spawn one or more units in a grid centred on `position`.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `unitDefName` | yes | string | Unit type to spawn |
| `teamID` | yes | number | Owning team |
| `position` | yes | Position | `{x, z}` centre of the grid |
| `unitName` | no | string | Track spawned units under this name |
| `quantity` | no | number | Number to spawn (default: 1) |
| `facing` | no | Facing | Direction: `'n'`/`'s'`/`'e'`/`'w'` or `0`–`3` |
| `construction` | no | boolean | If `true`, units spawn as ghosts being built |
| `spacing` | no | number | Extra spacing between units in the grid (elmos) |

```lua
{
    type = actionTypes.SpawnUnits,
    parameters = {
        unitName    = 'guards',
        unitDefName = 'armpw',
        teamID      = 1,
        position    = { x = 2000, z = 3000 },
        quantity    = 6,
        facing      = 'w',
        spacing     = 50,
    },
},
```

---

#### DespawnUnits

Remove all units tracked under a name.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `unitName` | yes | string | Tracked unit name |
| `selfDestruct` | no | boolean | Play self-destruct animation |
| `reclaimed` | no | boolean | Remove silently as if reclaimed (overrides `selfDestruct`) |

```lua
{ type = actionTypes.DespawnUnits, parameters = { unitName = 'decoys', reclaimed = true } },
```

---

#### TransferUnits

Give all tracked units to another team.

| Parameter | Required | Type |
|---|---|---|
| `unitName` | yes | string |
| `newTeam` | yes | number |

```lua
{ type = actionTypes.TransferUnits, parameters = { unitName = 'prize', newTeam = 0 } },
```

---

#### NameUnits

Assign a tracked name to existing units, filtered by team, type, or area.
At least one of `teamID`, `unitDefName`, or `area` is required.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `unitName` | yes | string | Name to assign |
| `teamID` | no | number | Restrict to this team |
| `unitDefName` | no | string | Restrict to this unit type |
| `area` | no | Area | Restrict to units inside this area |

```lua
{ type = actionTypes.NameUnits, parameters = { unitName = 'patrol', teamID = 1, unitDefName = 'armpw' } },
```

---

#### UnnameUnits

Stop tracking all units under a name.

| Parameter | Required | Type |
|---|---|---|
| `unitName` | yes | string |

```lua
{ type = actionTypes.UnnameUnits, parameters = { unitName = 'patrol' } },
```

---

### Features

#### CreateFeature

Spawn a feature at a position, optionally tracking it.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `featureDefName` | yes | string | Feature type |
| `position` | yes | Position | `{x, y, z}` |
| `featureName` | no | string | Track the feature under this name |
| `facing` | no | Facing | Direction |

```lua
{
    type = actionTypes.CreateFeature,
    parameters = {
        featureDefName = 'armllt_dead',
        position       = { x = 2500, y = 0, z = 2500 },
        featureName    = 'oldWreck',
        facing         = 'n',
    },
},
```

---

#### DestroyFeature

Remove all features tracked under a name.

| Parameter | Required | Type |
|---|---|---|
| `featureName` | yes | string |

```lua
{ type = actionTypes.DestroyFeature, parameters = { featureName = 'oldWreck' } },
```

---

### Loadout (dynamic)

#### SpawnLoadout

Spawn a batch of units and/or features mid-mission, the same format as `UnitLoadout` / `FeatureLoadout`.
At least one of `unitLoadout` or `featureLoadout` is required.

```lua
{
    type = actionTypes.SpawnLoadout,
    parameters = {
        unitLoadout = {
            { name = 'armck', x = 2000, z = 2000, team = 0, unitName = 'reinforcement' },
        },
        featureLoadout = {
            { name = 'corak_dead', x = 2100, z = 2000, resurrectAs = 'corak', featureName = 'wreck' },
        },
    },
},
```

---

### SFX

#### SpawnExplosion

Trigger an explosion using a weapon's damage and visual parameters.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `weaponDefName` | yes | string | Weapon definition name |
| `position` | yes | Position | `{x, y, z}` |
| `direction` | no | Position | `{x, y, z}` direction vector (default: `{0,0,0}`) |

```lua
{
    type = actionTypes.SpawnExplosion,
    parameters = {
        weaponDefName = 'armtele',
        position      = { x = 3000, y = 100, z = 3000 },
    },
},
```

---

### Media

#### PlaySound

Play a `.wav` file.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `soundfile` | yes | string | Path from repo root |
| `volume` | no | number | Playback volume |
| `position` | no | Position | `{x, y, z}` for positional audio |
| `enqueue` | no | boolean | If `true`, queued after other enqueued sounds |

```lua
{ type = actionTypes.PlaySound, parameters = { soundfile = 'sounds/mission/alarm.wav', volume = 0.8, enqueue = true } },
```

---

#### SendMessage

Print a message to the console.

| Parameter | Required | Type |
|---|---|---|
| `message` | yes | string |

```lua
{ type = actionTypes.SendMessage, parameters = { message = "Reinforcements incoming!" } },
```

---

#### AddMarker

Place a map marker. Supply `name` if you need to erase it later.

| Parameter | Required | Type |
|---|---|---|
| `position` | yes | Position |
| `label` | no | string |
| `name` | no | string |

```lua
{ type = actionTypes.AddMarker, parameters = { position = { x = 3000, y = 0, z = 3000 }, label = "Objective", name = 'obj1' } },
```

---

#### EraseMarker

Remove a named marker.

| Parameter | Required | Type |
|---|---|---|
| `name` | yes | string |

```lua
{ type = actionTypes.EraseMarker, parameters = { name = 'obj1' } },
```

---

#### DrawLines

Draw a polyline through a list of positions.

| Parameter | Required | Type | Description |
|---|---|---|---|
| `positions` | yes | Positions | At least two `{x, y, z}` points |

```lua
{
    type = actionTypes.DrawLines,
    parameters = {
        positions = {
            { x = 1000, y = 0, z = 1000 },
            { x = 2000, y = 0, z = 1500 },
            { x = 3000, y = 0, z = 1000 },
        },
    },
},
```

---

#### ClearAllMarkers

Remove all map markers and lines.

```lua
{ type = actionTypes.ClearAllMarkers },
```

---

### Win conditions

#### Victory / Defeat

End the game. `Victory` declares the listed ally teams as winners; `Defeat` declares them as losers (all other teams win).

| Parameter | Required | Type |
|---|---|---|
| `allyTeamIDs` | yes | table of numbers |

```lua
{ type = actionTypes.Victory, parameters = { allyTeamIDs = { 0 } } },
{ type = actionTypes.Defeat,  parameters = { allyTeamIDs = { 1 } } },
```

---

### Other

#### AddResources

Immediately add metal and/or energy to a team.

| Parameter | Required | Type |
|---|---|---|
| `teamID` | yes | number |
| `metal` | no | number |
| `energy` | no | number |

```lua
{ type = actionTypes.AddResources, parameters = { teamID = 0, metal = 500, energy = 2000 } },
```

---

#### Custom

Run arbitrary Lua code.

| Parameter | Required | Type |
|---|---|---|
| `function` | yes | function |

```lua
{ type = actionTypes.Custom, parameters = { ['function'] = function() Spring.Echo("custom!") end } },
```

---

## Stages and Objectives

Stages and objectives are displayed in the mission UI.

```lua
local objectives = {
    captureBase = {
        text   = "Capture the enemy base.",  -- required
        amount = 1,                           -- optional; used for progress tracking
    },
    buildUnits = {
        text   = "Build 5 tanks.",
        amount = 5,
    },
}

local stages = {
    intro = {
        title      = "Introduction",            -- required
        objectives = { 'captureBase' },         -- optional; objective IDs shown in this stage
    },
    assault = {
        title      = "Assault",
        objectives = { 'buildUnits', 'captureBase' },
    },
}
```

- Every objective must be referenced by at least one stage.
- `InitialStage` must be a key in `Stages` (defaults to `"initialStage"`).

---

## Loadouts

Units and features to spawn before the first frame.

```lua
local unitLoadout = {
    -- Required: name, x, z, team
    -- Optional: y (defaults to ground height), facing, unitName, neutral
    { name = 'armck',   x = 1780, z = 1850, team = 0, facing = 'e', unitName = 'player-con' },
    { name = 'armllt',  x = 2000, z = 2000, team = 1 },
}

local featureLoadout = {
    -- Required: name, x, z
    -- Optional: y, facing, featureName, resurrectAs
    { name = 'corak_dead', x = 1900, z = 1800, facing = 's', resurrectAs = 'corak', featureName = 'wreck1' },
    { name = 'armfus_dead', x = 2100, z = 1800 },
}
```

### Unit loadout fields

| Field | Required | Type | Description |
|---|---|---|---|
| `name` | yes | string | Unit definition name |
| `x`, `z` | yes | number | Map coordinates |
| `team` | yes | number | Owning team |
| `y` | no | number | Height (defaults to ground height) |
| `facing` | no | Facing | Direction |
| `unitName` | no | string | Track this unit under the given name |
| `neutral` | no | boolean | If `true`, the unit belongs to no team |

### Feature loadout fields

| Field | Required | Type | Description |
|---|---|---|---|
| `name` | yes | string | Feature definition name |
| `x`, `z` | yes | number | Map coordinates |
| `y` | no | number | Height |
| `facing` | no | Facing | Direction |
| `featureName` | no | string | Track this feature under the given name |
| `resurrectAs` | no | string | Unit definition name to resurrect into |

---

## Named units and features

Many triggers and actions filter or act on **named** units or features. A name groups any number of units/features under a single string identifier.

Names are created by:
- `SpawnUnits` with `unitName`
- `NameUnits`
- `UnitLoadout` / `FeatureLoadout` / `SpawnLoadout` entries with `unitName` or `featureName`
- `CreateFeature` with `featureName`

Names are consumed by:
- `IssueOrders`, `DespawnUnits`, `TransferUnits`, `UnnameUnits`
- `DestroyFeature`
- `UpdateObjective` (for progress tracking)
- Trigger parameters: `unitName`, `featureName`

The validator will warn about names that are created but never referenced, and names that are referenced but never created.

---

## Facing values

All `facing` parameters accept any of the following:

| Value | Direction |
|---|---|
| `'n'` or `'north'` or `0` | North |
| `'s'` or `'south'` or `1` | South |
| `'e'` or `'east'` or `2` | East |
| `'w'` or `'west'` or `3` | West |

---

## Area values

All `area` parameters accept either a rectangle or a circle:

```lua
-- Rectangle (x1 < x2, z1 < z2):
area = { x1 = 1000, z1 = 1000, x2 = 2000, z2 = 2000 }

-- Circle:
area = { x = 1500, z = 1500, radius = 500 }
```

---

## Minimal complete example

```lua
local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes  = GG['MissionAPI'].ActionTypes

local objectives = {
    destroyEnemy = { text = "Destroy the enemy commander." },
}

local stages = {
    main = { title = "Destroy the Enemy", objectives = { 'destroyEnemy' } },
}

local triggers = {
    start = {
        type       = triggerTypes.TimeElapsed,
        parameters = { gameFrame = 30 },
        actions    = { 'spawnEnemy', 'messageStart' },
    },
    enemyKilled = {
        type       = triggerTypes.UnitKilled,
        parameters = { unitName = 'enemy' },
        actions    = { 'winGame', 'objectiveDone' },
    },
}

local actions = {
    spawnEnemy = {
        type       = actionTypes.SpawnUnits,
        parameters = { unitName = 'enemy', unitDefName = 'corcom', teamID = 1, position = { x = 4000, z = 4000 } },
    },
    messageStart = {
        type       = actionTypes.SendMessage,
        parameters = { message = "Destroy the enemy commander!" },
    },
    objectiveDone = {
        type       = actionTypes.UpdateObjective,
        parameters = { objectiveID = 'destroyEnemy', completed = true },
    },
    winGame = {
        type       = actionTypes.Victory,
        parameters = { allyTeamIDs = { 0 } },
    },
}

local unitLoadout = {
    { name = 'armcom', x = 2000, z = 2000, team = 0, facing = 's' },
}

return {
    InitialStage   = 'main',
    Stages         = stages,
    Objectives     = objectives,
    Triggers       = triggers,
    Actions        = actions,
    UnitLoadout    = unitLoadout,
}
```
