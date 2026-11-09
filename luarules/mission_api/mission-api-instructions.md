# Mission API instructions

Read this before touching `luarules/mission_api/`, `luarules/gadgets/api_mission*.lua`,
`singleplayer/`, or `spec/mission_api/`. It covers only what is specific to this subsystem; the
general rules live in `.github/agents.md`.

## The system

A data-driven mission runtime: a mission is a plain Lua table of stages, objectives, triggers, and
actions, and the runtime is generic and knows no individual mission.

- Everything is synced. Pausing goes through `GG.GamePause` (from `api_game_pause.lua`) and player
  text through the battle log (see Runtime surfaces), because synced code can do neither.
- Missions live in `singleplayer/` (tests in `singleplayer/mission-api-tests/`) and are included by
  path from `entryPoint` in the `missionoptions` modoption, which `game_setup.lua` reads.

## Load order

Nothing works outside this sequence, so start here when something reads as `nil`.

1. `api_missions.lua` (layer 0, synced) `Initialize()` creates `GG['MissionAPI']` and `VFS.Include`s
   the modules into `.Modules` in a fixed order, `ParameterTypes` first because every other file
   reads it at load time.
2. `actions_loader.LoadActionDefinitions()` then `triggers_loader.LoadTriggerDefinitions()` scan
   their directories into `GG['MissionAPI'].ActionDefinitions` and `.TriggerDefinitions`.
3. `loadMission(gameSetup)` includes the mission file, validates it with `validation.lua`, runs the
   four `*_loader` normalizers, resolves difficulties, then variable references (`variables.lua`),
   then runs `parameter_processing.lua`.
4. `api_missions_triggers.lua` (layer 1) `Initialize()` binds the definitions and unsubscribes the
   hot call-ins the mission does not need.

- Module and definition files run at include time and read `GG['MissionAPI']` directly, so never
  read at load time something registered later in the sequence; read it in a function or in
  `Initialize()`. `validation.lua` reads the definitions per call for this reason.
- Steps 1 to 3 run under `xpcall`, because `gadgets.lua` calls `Initialize()` unprotected and an
  escaping error kills the whole LuaRules handle.
- A Lua error there fails the mission like a validation error, reported under `Loading`, the first
  section `validation/report.lua` logs. The message names the file that failed to load, taken from
  the error message, or the step: loading the Mission API, validating the mission or processing it.
- The dev-mode traceback stops at `VFS.Include`, which runs each file in its own `pcall`; an error
  raised while a file loads, syntax errors included, carries file and line in its message.

### Type IDs

- `triggers_loader` numbers trigger types from `ipairs(VFS.DirList(...))`, and `actions_loader` runs
  a counter over `VFS.SubDirs`. Missions author `type = triggerTypes.TimeElapsed` (`triggerTypes`
  is `GG['MissionAPI'].TriggerDefinitions.Types`, `actionTypes` likewise), so the string never
  reaches the runtime: `trigger.type` and `action.type` are integers, and the schema tables
  (`Parameters`, `Functions`, `Callins`) are keyed by them.
- Adding or renaming a file renumbers types, so compare against `triggerTypes.X` or
  `actionTypes.X`, never a literal, and never persist, network, or hard-code an ID.

## Runtime surfaces

- `GG['MissionAPI']` holds the definitions, the normalized mission, the mutable tracking tables
  (`trackedUnitNames`, `markerNames`, `soundQueue`, `BattleLogRaw`, and more), and `Modules`; it is
  cleared on `Shutdown`.
- Unit and feature identity is by name, not ID; go through `Modules.Tracking`, and never index the
  tracking tables directly.
- Player text goes through `Modules.BattleLog.AddMessage(messageType, messageKey, messageData)`,
  with `messageType` from the `MessageType` enum in `parameter_types.lua` and `messageKey` an I18N
  key. Synced code cannot translate, so entries are published as game rules params and
  `luaui/Widgets/api_mission_battle_log.lua` translates them into `WG.MissionAPI.BattleLog`; the
  `Spring.Echo` in `AddMessage` is a placeholder until a widget displays the log.

## Adding a trigger type

One file per type in `luarules/mission_api/triggers/`, snake_case, returning one table:

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

- A type that overlaps an existing one becomes a parameter on it, or is narrowed until they differ.
  Add no type that no mission needs, or that only forwards a call-in.
- The call-in key is one `api_missions_triggers.lua` already forwards, an engine call-in or a
  synthetic one (`DetectionUpdate`, `CountdownTick`, `CountdownEnded`); otherwise add the gadget
  call-in plus its `dispatchTriggerCallin` line.
- `dispatchTriggerCallin` runs a handler once per trigger of its type, passing
  `(trigger, triggerID, context, ...call-in args)`, and does not filter for you. An omitted filter
  matches everything (hence `requiresOneOf`), and `teamName` means that team alone, not its allies.
- `Initialize()` unsubscribes `AllowUnitBuildStep`, `AllowFeatureBuildStep`, `UnitBuildStepPost`,
  and `UnitDamaged` unless a loaded trigger needs them, so a new trigger on one of those extends the
  matching `needs*` check or silently never fires.
- Never fire actions yourself. `context.ActivateTrigger(trigger)` enforces the `settings` keys
  `active`, `prerequisites`, `stages`, `repeating` with `maxRepeats`, and `difficulties` (see
  Objectives and stages, and Difficulty), and returns `false` when the trigger was not eligible:
  `active`, `prerequisites`, and `stages` can pass later, `maxRepeats` and `difficulties` never
  will. Record a firing only on `true`, and decide what happens for each kind of refusal.
- `context` is the only route to shared bookkeeping (`DoesUnitHaveName`, `DwellingUnitsInAreas`,
  `ConstructionState`, `IsBuildFrameOwner`, and more); extend `triggerContext` rather than reach
  into gadget locals or duplicate state per trigger.
- Statistics triggers (`total_units_*`, `units_owned`) declare no `callins` and are evaluated
  centrally through `statistics.lua`; follow that pattern for anything needing shared counters.
- A trigger that holds state handles every event that can change its answer, which for units means
  moving, finishing, and the `MetaUnitAdded` and `MetaUnitRemoved` call-ins, which cover death and
  team changes; test both `repeating` settings.
- Prefer an event to a poll; with no event, poll at half a second (`0.5 * Game.gameSpeed`) as
  `seismic_contacts.lua` does, not every frame, unless units need to react fluidly.
- A handler runs on every call-in it listens to, so index a table built at load rather than scan
  one, and do table lookups before engine calls: `DoesUnitHaveName` before `Spring.GetUnitTeam`.

## Adding an action type

One file per action group in `luarules/mission_api/actions/<category>/`, returning an array of
definitions (usually one); the category directory is required because `actions_loader` scans one
level deep:

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

- One more parameter on an existing action may do the job.
- Behavior not specific to missions belongs in the repository's `modules/` or in the system that
  owns it, code two action files share in a module under `mission_api/`, and what a module
  already does is called, not copied.
- Behavior an action cannot finish in one call (currently the per-second resource drip) lives in
  `GG['MissionAPIActionHelper']` (`api_missions_action_helpers.lua`, synced); anything needing its
  own `GameFrame` accumulator goes there.
- `actions_dispatcher.Invoke` unpacks parameters positionally in schema order, trailing optionals
  included, so the schema order is the `actionFunction` signature, and reordering, inserting, or
  renaming a parameter breaks both the function and every mission using it.
- Action functions receive processed values: a `TeamName` parameter arrives as a team ID, so name
  the argument `teamID` and never look it up again (`GG['MissionAPI'].Teams` maps both ways, so
  `Teams[teamID]` returns the name instead of raising). Trigger handlers read the same value from
  `trigger.parameters.teamName`.
- An action uses no randomness, because the mission author relies on the outcome.
- An action does the obvious, safe thing by default; anything that can strand a unit or surprise the
  author needs an explicit parameter.
- Mission data is read-only once processed, and an action can run many times, so copy an order or
  its options before changing them.
- Engine calls run call-ins synchronously, so destroying a unit can fire a trigger whose actions
  change the table being walked; walk a copy, and name that re-entry in the comment.
- Do not guard against what validation, the loaders, or the engine already guarantee (no `or {}` on
  a processed value). A dying unit keeps a valid ID until the engine removes it, so skip one only
  when the engine call would refuse it.
- A skipped order counts as absent, and the next order keeps its own options.
- Synced orders go straight to each unit, so what a player's client adds from its selection
  (formation moves, group speed, wait commands) does not happen. Give a unit its whole list with
  `Spring.GiveOrderArrayToUnit`.

## Adding a parameter type

- Declare types from `parameter_types.lua`, enums included (members of `Enums`, never a string),
  and add a new one only when no existing one fits.
- A value with a unit gets its own type, since a bare `Number` hides its meaning from the editor:
  positions are `Position`, never separate `Number`s, time is seconds, and units and teams are the
  author's names, never IDs.
- Register a validator in `validation/parameter_validators.lua`, shaped like the existing ones; an
  unvalidated type silently accepts anything. A value is checked there once, never downstream, and
  a validator writes no state.
- Register a processor in `parameter_processing.lua` when the type needs normalizing (team names to
  IDs, ground height for `Position`). The action or trigger sees the processed value and a spec
  calling `actionFunction` directly does not, so tests pass processed-shaped data.
- The editor reads the schemas, not validators, so express mutual exclusion with `requiresOneOf` or
  one parameter taking both forms.
- `validation/references.lua` cross-checks unit, feature, marker, line, and effect names and
  countdown and cutscene IDs between creator and consumer; it reads the consuming types from the
  schemas, so a new parameter of one of those types needs no listing.
- Types and validators are generic, so neither the name nor the comments mention the action that
  prompted one.
- Parameter names follow the existing ones (`teamName`, `unitName`, `markerName`), take the more
  general word when two fit, and keep one term per concept across files; internal IDs are spelled
  `teamID`, never `teamId`.

## Validation

- Any validation error makes `api_missions.lua` drop `GG['MissionAPI']`, which makes
  `api_missions_triggers.lua` remove itself and ends the game once it starts, so reserve errors for
  unrunnable missions and report warnings otherwise.
- Everything reported while a mission loads goes through `validation/report.lua`, never a second
  logging path; keep code faults distinguishable from mission faults: an error is the mission's
  only while its file loads or its data is processed.
- What a mission declares itself is shaped by the `*_schema.lua` files beside the loaders, plain
  data the editor reads and `validation/sections.lua` validates against; keep them in step with the
  loaders.
- Check against the schema or the defs rather than a hardcoded list, and warn only when the author
  can act on the warning.
- Validators report on any input, however badly formed, so wrap values in `tostring` in a message.
- `validation/parameter_validators.lua` lists the commands `AllowCommand` consumes, which never
  reach `UnitCommand`, so the `Command` validator warns rather than fails on them; keep the list
  current as gadgets change what they consume.

## Comments and naming

`CONTRIBUTING.md` has the general rule; these are the comments review removes most often here.

- Parameters, schema fields, and their comments are phrased for the mission author, by what the
  author gets (`skippable`); mechanism names (`publish`) stay in module code and commit messages.
- New entries go into the existing group in a table or a file, not at the end.
- An annotation types a value, a `---` doc line states a caller's contract, and a `--` comment gives
  a reason; none of them describes what the code does, records a fixed bug, or explains the engine.
- Schemas, `parameter_types.lua`, and `validation/parameter_validators.lua` carry no documentation:
  a note like "can be negative" or `Rectangle: { x1, z1, x2, z2 }` repeats the type and goes stale
  when it changes.
- Do not repeat a log message or restate a repository-wide pattern in a comment, and delete a
  comment the code no longer matches.
- A function that needs a comment to say what it does gets renamed; the name says what it does and
  what it acts on, in the vocabulary of the system it touches.
- Write the direct form: no helper for one table access, no packed parameter table, and no export
  without a caller.

## Testing

- CI skips `spec/mission_api/` on a pull request that changes none of the paths in
  `MISSION_SPEC_INPUTS` (`.github/workflows/test_unit.yml`); the nightly run still covers them, and
  `SPEC_SKIP=mission_api` skips them locally.
- `require("mission_api.spec_helper")` returns `MissionSpecEnv`, which holds the ambient globals the
  modules read at load time; its header says how. Per-test stubs go on the env (`env.Spring`,
  `env.UnitDefs`), and the helper is extended rather than re-stubbed per file.
- `MissionApiBuilder.new():...:Install()` (`spec/builders/mission_api_builder.lua`) builds
  `GG['MissionAPI']` fluently and records module calls under `mock.calls`; use it instead of
  hand-building one, re-`Install()` in `before_each` because the state is global, and keep mission
  terms out of the general builders.
- `require("mission_api.schema_spec_helper")` flattens a definition to
  `{ type = ..., param = "Type!" }` so the whole schema is one `assert.are.same`; every trigger and
  action spec asserts its schema this way, which catches a reorder breaking the positional dispatch.
- Test `actionFunction` and `callins.<Name>` directly with a hand-built `trigger` table and a
  `context` stub; never boot the gadgets.
- Each call-in a trigger listens to gets an assertion in `triggers_loader_spec.lua`.
- Each `it` covers one behavior, its description matches its assertions, and a normal case comes
  before any special case.
- A spy records everything it receives, so a reader never has to work out what it dropped.
- A stand-in behaves like the real thing: a fake `VFS.Include` fails the way the real one does, or
  the `xpcall` paths around it go untested.
- A module that a mission depends on being missing is an error, so no spec expects a quiet no-op.
- Test the sizes that break a shape, such as a grid of 2, 3, 5, and 8 units, not only the ones that
  fit it.

## Pull requests

- `Mission API:` is a pull request title prefix, not a commit subject prefix.
- A stacked pull request's description gives its scope and whether it is a refactor, which changes
  no behavior or schema, or a feature.

## Objectives and stages

- `objectives_loader` splits objectives in two: a trigger type with a `Quantity` parameter becomes a
  managed objective (metadata in `GG['MissionAPI'].ManagedObjectives`, evaluated centrally, nothing
  synthesized), and anything else synthesizes a trigger `__objective_<objectiveID>` and an action
  `__updateObjective_<objectiveID>` into the raw tables.
- Adding or removing a `Quantity` parameter on a trigger silently moves every objective using it
  between those two paths.
- The `__` prefixes are reserved, so mission scripts do not define IDs that collide.
- Stage membership comes from `Stages[stageID].objectives` and is copied onto the synthesized
  trigger's `settings.stages`; `stages_loader` is otherwise a pass-through.
- `objective.textKey` is an I18N key with no LuaUI consumer yet; `objectives.lua` only
  `Spring.Echo`s updates, so do not assume a UI reads it.

## Difficulty

- `difficulties.json` is the enum shared with the client (`Story = 1`, `Easy = 2`, `Medium = 3`,
  `Hard = 4`; higher is harder).
- `GG['MissionAPI'].Difficulty` is fixed per playthrough from `missionoptions.difficulty`
  (`Difficulty.FromName`); a missing or unknown name falls back to the lowest in the enum.
- `settings.difficulties`, the per-trigger gate, is an array of names with no inheritance between
  difficulties; empty or omitted enables the trigger on every difficulty, and after validation the
  names become values for the runtime check in `api_missions_triggers.lua`.
- Any trigger parameter, action parameter, objective field, or cutscene field may be authored per
  difficulty, as in `seconds = { difficulties = { Medium = 60, Hard = 30 } }`; resolution picks the
  exact difficulty, else the highest specified one below it, else the lowest specified one.
- Detection is by a non-nil `difficulties` key, not by Lua type, so table parameters (`Area`,
  `Orders`) work the same way.
- Structural fields (`type`, `settings`, `actions`, an objective's `trigger`) and fields nested
  inside loadout entries or orders do not support it; author the whole parameter per difficulty
  instead.
- Difficulties tables survive validation so every difficulty's value is checked, and the loaders run
  before the resolve, so a loader does not consume parameter values: `objectives_loader` leaves a
  difficulty-dependent `amount` alone, and the resolve pass derives `maxRepeats` from it.

## Work in flight

- The API is in its version zero. There are no missions that can be "broken" by changes, then.
- Co-op is declared but not implemented (`settings.coop` and `objective.coop` are parsed and
  validated, and the `isTriggerValid` check is commented out), so do not build on it.
- `TODO`s in `api_missions.lua` (loader refactor after the loadouts merge) and in
  `actions/units/move_units.lua` and `rotate_units.lua` (`CompassAngleToHeading`) mark work in
  flight; check with the author before refactoring around them.
