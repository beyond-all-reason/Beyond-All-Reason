# Mission API instructions

Read this before touching `luarules/mission_api/`, `luarules/gadgets/api_missions*.lua`, `singleplayer/`, or
`spec/mission_api/`. It covers only what is specific to this subsystem; general repository rules live in
`.github/copilot-instructions.md`, including the rule that a change altering anything described below updates this
file in the same pull request.

## What it is

A data-driven mission runtime. A mission is a plain Lua table of **stages**, **objectives**, **triggers**, and
**actions**; the engine-facing code is generic and knows nothing about any individual mission. Everything is synced;
what synced code cannot do, pausing and showing translated text, goes through `GG.GamePause` and the battle
log (see Runtime surfaces).

## Load order

Nothing here works outside this sequence, so keep it in mind when something reads as `nil`:

1. `api_missions.lua` (layer 0, synced) `Initialize()` creates `GG['MissionAPI']`, then `VFS.Include`s the modules
   into `GG['MissionAPI'].Modules` **in a fixed order** — `ParameterTypes` first, because every other file reads it
   at load time.
2. `actions_loader.LoadActionDefinitions()` then `triggers_loader.LoadTriggerDefinitions()` scan their directories
   and populate `GG['MissionAPI'].ActionDefinitions` / `.TriggerDefinitions`.
3. `loadMission(gameSetup)` includes the mission named by the startscript, validates the raw mission with
   `validation.lua`, runs the four `*_loader` normalisers, resolves difficulties, then variable references (`variables.lua`), then runs
   `parameter_processing.lua`.
4. `api_missions_triggers.lua` (layer 1) `Initialize()` binds the definitions and unsubscribes from hot call-ins the
   loaded mission does not need.

Steps 1 to 3 run under `xpcall`: `gadgets.lua` calls `Initialize()` unprotected, and an error escaping it kills the
whole LuaRules handle. A Lua error in them fails the mission the way a validation error does (below), and the message
names where it came from: the file that failed to load (the mission file or a Mission API module, by the path in the
engine's include error), or else the step: loading the Mission API, validating the mission or processing it. The
dev-mode traceback stops at `VFS.Include`, which runs each file in its own `pcall`; for an error raised while a file
loads, syntax errors included, the message itself carries the file and line.

Module and definition files run at include time and read `GG['MissionAPI']` directly. Never add a load-time read of
something registered later in that sequence; move it into a function or into `Initialize()`. `validation.lua` reads
the definitions per call rather than at include time, so that including it does not pin it to one load order.

## Type IDs are directory-order integers

`triggers_loader` assigns each trigger type an integer from `ipairs(VFS.DirList(...))`; `actions_loader` does the
same with a running counter over `VFS.SubDirs`. Missions author `type = triggerTypes.TimeElapsed`, so the string name
never reaches the runtime — `trigger.type` and `action.type` are integers, and the schema tables
(`Parameters`, `Functions`, `Callins`) are keyed by them.

Consequences:

- **Adding or renaming a file renumbers other types.** IDs are valid for one session only. Never persist, network,
  hard-code, or compare them across loads.
- Compare against `triggerTypes.X` / `actionTypes.X`, never a literal.

## Adding a trigger type

One file per type in `luarules/mission_api/triggers/`, snake_case, returning a single table:

```lua
local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'UnitKilled',                                  -- PascalCase, unique, matches the file name
	parameters = {
		{ name = 'unitName', required = false, type = ParameterTypes.UnitName },
		requiresOneOf = { 'unitName', 'unitDefName' },    -- optional, on the array itself
	},
	callins = {
		UnitDestroyed = function(trigger, triggerID, context, unitID, unitDefID, unitTeam)
			-- filter on trigger.parameters, then:
			context.ActivateTrigger(trigger)
		end,
	},
}
```

- Handlers get `(trigger, triggerID, context, ...call-in args)`. `dispatchTriggerCallin` in
  `api_missions_triggers.lua` runs your handler once per trigger of your type; it does not filter for you.
- **Never fire actions yourself.** Call `context.ActivateTrigger(trigger)`; it enforces `active`, `prerequisites`,
  `stages`, `repeating`/`maxRepeats`, and `difficulties`, and returns `false` when the trigger was not eligible.
- `context` is the only sanctioned way to reach shared bookkeeping (`DoesUnitHaveName`, `DwellingUnitsInAreas`,
  `ConstructionState`, `IsBuildFrameOwner`, …). Extend `triggerContext` rather than reaching
  into gadget locals or duplicating state per trigger.
- The call-in key must be one `api_missions_triggers.lua` already forwards — an engine call-in or a synthetic
  dispatch (e.g. `DetectionUpdate`, `CountdownTick`, `CountdownEnded`). If it is not forwarded yet, add the gadget
  call-in plus its `dispatchTriggerCallin` line.
- `AllowUnitBuildStep`, `AllowFeatureBuildStep`, and `UnitBuildStepPost` are unsubscribed in `Initialize()` unless a
  loaded trigger needs them. A new trigger on one of those must extend the matching `needs*` check, or it will
  silently never fire.
- Statistics triggers (`total_units_*`, units-owned style) deliberately declare **no** `callins`; they are evaluated
  centrally through `statistics.lua`. Follow that pattern for anything needing shared counters.

## Adding an action type

One file per action group in `luarules/mission_api/actions/<category>/` — the category subdirectory is **required**,
`actions_loader` only scans one level deep. The file returns an **array** of definitions (usually one):

```lua
return {
	{
		type = 'AddMapMarker',
		parameters = {
			{ name = 'markerName', required = true,  type = ParameterTypes.String },
			{ name = 'position',   required = true,  type = ParameterTypes.Position },
			{ name = 'markerType', required = false, type = ParameterTypes.String },
			{ name = 'label',      required = false, type = ParameterTypes.String },
		},
		actionFunction = addMapMarker,
	},
}
```

`actions_dispatcher.Invoke` unpacks parameters **positionally, in schema order**, including trailing optionals. So
the schema array order *is* the `actionFunction` signature: reordering, inserting, or renaming a parameter is a
breaking change to both the function and every mission using it.

## Parameters, validation, processing

- Declare types from `parameter_types.lua`; add a new type there only when no existing one fits, and register a
  validator for it in `validation/parameter_validators.lua` (a function returning `nil` or a list of
  `{ message = ... }`, with optional `isWarning = true` and `parameterNameSuffix` for nested fields). An unvalidated
  type silently accepts anything.
- `parameter_processing.lua` rewrites values after validation (ground height for `Position`, unit-def names to
  negative build command IDs for `Orders`/`Command`, `.wav` length caching for `SoundFile`, enum lists to sets). If
  your type needs normalisation, register a processor there — the action/trigger sees the processed value, and specs
  that call `actionFunction` directly do not, so pass processed-shaped data in tests.
- Any validation error makes `api_missions.lua` drop `GG['MissionAPI']`, which in turn makes
  `api_missions_triggers.lua` remove itself, and ends the game once it starts. Validation failure aborts the whole
  mission — reserve errors for genuinely unrunnable missions and report warnings otherwise. A Lua error while the
  mission loads, one in the validation code included, ends it the same way but is reported as a Lua error in the
  step that raised, not as a validation error.
- `validation/references.lua` cross-checks unit/feature/marker/line names, countdown IDs and cutscene IDs between
  where they are created or defined and the actions and triggers that consume them. The consuming types are read from
  the schemas, so an action or trigger declaring a `UnitName`, `FeatureName`, `CountdownID` or `CutsceneID` parameter
  is picked up without being listed.
- The shape of the objects a mission declares itself, rather than of a trigger or action, lives in a schema file
  next to the loaders: `stages_schema.lua` (stage fields), `objectives_schema.lua` (objective fields),
  `triggers_schema.lua` (the settings every trigger shares), `countdowns_schema.lua` and `cutscenes_schema.lua`. They are plain data, so
  tools and the mission editor can read them; `validation/sections.lua` validates against them. Keep them in step
  with the loaders.

## Difficulty

- `difficulties.json` is the difficulty enum, shared with the client: name → difficulty (`Story = 1`, `Easy = 2`,
  `Medium = 3`, `Hard = 4`), higher is harder. `GG['MissionAPI'].Difficulty` holds the current difficulty, fixed
  per playthrough — nothing re-resolves at runtime. Until a selection source exists, `api_missions.lua`
  `Initialize()` defaults it to the lowest difficulty in the enum.
- Any trigger parameter, action parameter, or objective field may be authored per difficulty:
  `seconds = { difficulties = { Medium = 60, Hard = 30 } }`. Resolution picks the exact difficulty, else the
  highest specified one below it, else the lowest specified one. Detection is by a non-nil `difficulties` key, not
  by Lua type, so table parameters (`Area`, `Orders`, …) work the same way. Structural fields (`type`, `settings`,
  `actions`, an objective's `trigger`) and fields nested inside loadout entries or orders do not support it —
  author the whole parameter per difficulty instead.
- Difficulties tables survive validation so that every difficulty's value is validated, including values under
  invalid difficulty names; `loadMission` resolves everything in place (`Modules.Difficulty`) after the loaders and
  before `parameter_processing`. Code running **before** that must not consume parameter values —
  `objectives_loader` leaves a difficulty-dependent `amount` alone, and the resolve pass fills in the `maxRepeats`
  derived from it.
- `settings.difficulties` (the per-trigger on/off gate) is an array of difficulty names with **no** inheritance
  between difficulties; empty or omitted enables the trigger on every difficulty. After validation the names are
  converted to difficulty values for the runtime check in `api_missions_triggers.lua`.

## Objectives and stages

- `objectives_loader` splits objectives in two. A trigger type with a `Quantity` parameter becomes a **managed
  objective** (metadata pushed into `GG['MissionAPI'].ManagedObjectives`, evaluated centrally, no synthesis).
  Anything else **synthesises** a trigger `__objective_<objectiveID>` and an action `__updateObjective_<objectiveID>`
  into the raw tables. Adding or removing a `Quantity` parameter from a trigger silently moves every objective using
  it between those two paths.
- Those `__` prefixes are reserved; mission scripts must not define IDs that collide.
- Stage membership comes from `Stages[stageID].objectives`, and is copied onto the synthesised trigger's
  `settings.stages`. `stages_loader` is otherwise a pass-through.
- `objective.textKey` is an I18N key, but there is currently **no LuaUI consumer** — `objectives.lua` only
  `Spring.Echo`s updates. Do not assume a UI reads it.

## Runtime surfaces

- `GG['MissionAPI']` — definitions, the normalised mission, mutable tracking tables (`trackedUnitNames`,
  `markerNames`, `soundQueue`, `BattleLogRaw`, …), and `Modules`. Cleared on `Shutdown`.
- Text for the player goes through `Modules.BattleLog.AddMessage(messageType, messageKey, messageData)`, with
  `messageType` from the `MessageType` enum in `parameter_types.lua` and `messageKey` an I18N key. Synced code
  cannot translate, so each entry is appended to `BattleLogRaw`, published as a game rules param
  (`missionBattleLog_<n>` as JSON, plus `missionBattleLogCount`), and announced through `api_mission_battle_log.lua`
  (unsynced gadget) as `Script.LuaUI.MissionBattleLogChanged`. `luaui/Widgets/api_mission_battle_log.lua` reads the
  params on that call and at start (so also after a `/luaui reload`), rebuilds the text on `LanguageChanged`, and
  holds the translated log oldest-first in `WG.MissionAPI.BattleLog`. The `Spring.Echo` in `AddMessage` is a
  placeholder until a widget displays the log.
- `GG['MissionAPIActionHelper']` (`api_missions_action_helpers.lua`, synced) — for behaviour an action cannot do in
  one call, currently per-second resource drip. Put anything needing its own `GameFrame` accumulator here rather
  than growing the action file.
- Unit and feature identity is by **name**, not ID: go through `Modules.Tracking`, never index the tracking tables
  directly.

## Mission scripts

Missions live in `singleplayer/` and are included by path. `api_missions.lua:Initialize()` holds a commented-out
list of `mission-api-tests/*` paths with one active — that is a development harness. Changing which line is active
is a deliberate, reviewable change; do not leave a debug selection in a patch, and do not treat the active path as
meaningful.

## Testing

Specs mirror the source tree under `spec/mission_api/` and are the primary way to verify this subsystem.

- `require("mission_api.spec_helper")` returns `MissionSpecEnv`. `new(overrides)` builds a `SpecEnv` holding the
  ambient globals the modules read at load time (`math.bit_and`, team layout, `CMD`/`GameCMD`), `include(env, path)`
  loads the code under test into it, and `registerModules(env)` loads `Modules.ParameterTypes` and the other shared
  modules. The shared globals are sealed, so per-test stubs go on `env.Spring` and the like. Extend it instead of
  re-stubbing per file.
- `Builders.MissionApi.new():...:Install()` (from `spec/builders/index.lua`) builds `GG['MissionAPI']` fluently
  (`WithTrackedUnit`, `WithTrigger`, `WithCurrentStage`, `WithModule`, …) and records module calls under
  `mock.calls`. Re-`Install()` in `before_each`; state is global and leaks between tests otherwise.
- `require("mission_api.schema_spec_helper")` flattens a definition to `{ type = ..., param = "Type!" }` so the
  whole schema is one `assert.are.same`. Every trigger and action spec should assert its schema this way — that is
  what catches an accidental parameter reorder breaking the positional dispatch.
- Test `actionFunction` and `callins.<Name>` directly with a hand-built `trigger` table and a `context` stub; do not
  try to boot the gadgets.

## Known rough edges

- Co-op is declared but not implemented: `settings.coop` and `objective.coop` are parsed and validated, and the
  `isTriggerValid` check is commented out. Do not build on it.
- `TODO`s in `api_missions.lua` (loader refactor after loadouts merge) and `actions/units/move_units.lua`
  (`CompassAngleToHeading`) mark work in flight — check with the author before refactoring around them.
- `validation.lua` maintains a list of commands consumed in `AllowCommand` that therefore never reach
  `UnitCommand`; order-related triggers warn rather than fail on them. Keep that list current when gadgets elsewhere
  change their consume behaviour.
