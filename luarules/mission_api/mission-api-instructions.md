# Mission API instructions

Read this before touching `luarules/mission_api/`, `luarules/gadgets/api_missions*.lua`, `singleplayer/`, or
`spec/mission_api/`. It covers only what is specific to this subsystem; general repository rules live in
`.github/copilot-instructions.md`, including the rule that a change altering anything described below updates this
file in the same pull request.

## What it is

A data-driven mission runtime. A mission is a plain Lua table of **stages**, **objectives**, **triggers**, and
**actions**; the engine-facing code is generic and knows nothing about any individual mission. Everything is synced.

## Load order

Nothing here works outside this sequence, so keep it in mind when something reads as `nil`:

1. `api_missions.lua` (layer 0, synced) `Initialize()` creates `GG['MissionAPI']`, then `VFS.Include`s the modules
   into `GG['MissionAPI'].Modules` **in a fixed order** — `ParameterTypes` first, because every other file reads it
   at load time.
2. `actions_loader.LoadActionDefinitions()` then `triggers_loader.LoadTriggerDefinitions()` scan their directories
   and populate `GG['MissionAPI'].ActionDefinitions` / `.TriggerDefinitions`.
3. `loadMission(scriptPath)` includes the mission from `singleplayer/`, runs the four `*_loader` normalisers, then
   `validation.lua`, then `parameter_processing.lua`.
4. `api_missions_triggers.lua` (layer 1) `Initialize()` binds the definitions and unsubscribes from hot call-ins the
   loaded mission does not need.

Module and definition files run at include time and read `GG['MissionAPI']` directly. Never add a load-time read of
something registered later in that sequence; move it into a function or into `Initialize()`.

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
- `context` is the only sanctioned way to reach shared bookkeeping (`DoesUnitHaveName`, `GetUnitsInArea`,
  `PreviousUnitsInAreas`, `ConstructionState`, `IsBuildFrameOwner`, …). Extend `triggerContext` rather than reaching
  into gadget locals or duplicating state per trigger.
- The call-in key must be a real engine call-in that `api_missions_triggers.lua` already forwards. If it does not,
  add the gadget call-in plus its `dispatchTriggerCallin` line.
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
		type = 'AddMarker',
		parameters = {
			{ name = 'position', required = true,  type = ParameterTypes.Position },
			{ name = 'label',    required = false, type = ParameterTypes.String },
		},
		actionFunction = addMarker,
	},
}
```

`actions_dispatcher.Invoke` unpacks parameters **positionally, in schema order**, including trailing optionals. So
the schema array order *is* the `actionFunction` signature: reordering, inserting, or renaming a parameter is a
breaking change to both the function and every mission using it.

## Parameters, validation, processing

- Declare types from `parameter_types.lua`; add a new type there only when no existing one fits, and register a
  validator for it in `validation.lua` (a curried function returning `nil` or a list of `{ message = ... }`, with
  optional `severity = "warning"` and `parameterNameSuffix` for nested fields). An unvalidated type silently accepts
  anything.
- `parameter_processing.lua` rewrites values after validation (ground height for `Position`, unit-def names to
  negative build command IDs for `Orders`/`Command`, `.wav` length caching for `SoundFile`, enum lists to sets). If
  your type needs normalisation, register a processor there — the action/trigger sees the processed value, and specs
  that call `actionFunction` directly do not, so pass processed-shaped data in tests.
- `logError` sets `HasValidationErrors`, which makes `api_missions.lua` drop `GG['MissionAPI']` and remove itself,
  which in turn makes `api_missions_triggers.lua` remove itself. Validation failure aborts the whole mission —
  reserve `logError` for genuinely unrunnable missions and use `logWarn` otherwise.
- `ValidateReferences` cross-checks unit/feature/marker names between the actions that create them and the actions
  and triggers that consume them, via hard-coded type sets near the bottom of `validation.lua`. A new action that
  names or references units, features, or markers must be added to those sets.

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
  `markerNames`, `soundQueue`, …), and `Modules`. Cleared on `Shutdown`.
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

- `require("mission_api.spec_helper")` returns `registerMissionApiModules`, which installs the ambient globals the
  modules read at load time (`math.bit_and`, team layout, `CMD`/`GameCMD`, `Modules.ParameterTypes`). Extend it
  instead of re-stubbing per file.
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
