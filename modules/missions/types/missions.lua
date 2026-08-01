---@meta actions

--- Mission-runtime types: trigger engine descriptors and the authoring DSL's
--- chain/condition/effect shapes, dot-only and closure-free. Mission files must load identically in the synced sandbox (which strips rawset) and in busted.

--- Domain aliases: the DSL's typed parameters. Names are LOAD-BEARING beyond
--- the checker — the mission kit derives its semantic model from them (alias -> slot semantic, literal unions -> editor enums).
---@alias UnitDefName string unit def name, e.g. "armpw"
---@alias MissionUnitName string roster unit name, declared by units.lua Named(...)
---@alias MissionUnitGroup string roster group name, declared by units.lua Grouped(...)
---@alias ObjectiveName string
---@alias MissionTeamRole "player"|"enemy"|"gaia" spawn-time team role, resolved at arm
--- Wall-clock seconds, never frames. An alias and not a bare number for the
--- usual reason — a `number` has nothing to call itself in a sentence, so an
--- editor can only offer a nameless box, and the one thing an author needs to
--- know here is which unit they are typing in. The DSL converts on the way in
--- using the engine's own tick rate, so "30" is thirty seconds at any speed.
---@alias MissionSeconds number

--- Mission bus vocabulary, CLOSED BY TYPE: every event name crossing the bus
--- is a member of this alias, so the checker flags typos across every inputs/OnEvent consumer as type errors.
---@alias MissionEventName
---| "UnitFinished"
---| "UnitDestroyed"
---| "UnitGiven"
---| "UnitTaken"
---| "UnitEnteredLos"
---| "mission.objective_changed"
---| "waves.wave_spawned"
---| "waves.wave_cleared"
---| "waves.boss_spawned"
---| "waves.boss_defeated"

--- A condition carries metadata about what can change its answer: inputs
--- name bus events (nil = poll every cadence). Pure — reads only ctx, captures configuration never progress (progress lives in engine state, the savegame rule).
---@class MissionCondition
---@field evaluate fun(ctx: MissionContext): boolean
---@field inputs MissionEventName[]|nil events that can change this answer; nil = poll every cadence

--- What the engine hands every condition and effect: the gadget builds it
--- from Spring, specs from plain tables. Unit destroyed/spotted answers are latched — once true, stay true.
---@class MissionContext
---@field GetUnitDefCount fun(teamID: integer, unitDefName: string): integer count of finished units of that def
---@field IsObjectiveComplete fun(name: string): boolean
---@field IsUnitDestroyed fun(name: string): boolean
---@field IsUnitSpotted fun(name: string, allyTeamID: integer): boolean
---@field TransferGroup fun(groupName: string, teamID: integer)
---@field Protect fun(name: string) combat-module protection by roster name
---@field Unprotect fun(name: string)
---@field StartWaves fun(request: table) waves-module pressure, by pack
---@field StopWaves fun(pack: string)
---@field SetWaveIntensity fun(pack: string, intensity: number)
---@field SurgeWaves fun(pack: string)
---@field WaveStatus fun(pack: string): WaveStatus|nil
---@field frame integer current game frame

--- A lazy effect built by a named verb (e.g. Objective("x").Complete()); the
--- engine executes it when the trigger fires. Captures configuration only, never progress.
---@class MissionEffect
---@field execute fun(ctx: MissionContext)

--- The injected Objective verb's handle: Complete() builds the effect side,
--- IsComplete() the condition side.
---@class MissionObjective
---@field Complete fun(): MissionEffect
---@field IsComplete fun(): MissionCondition

--- A named-unit reference produced by the injected Unit verb. Both
--- conditions are latched; the name is validated against the roster at load — unknown names never arm.
---@class MissionUnitRef
---@field name MissionUnitName
---@field IsDestroyed fun(): MissionCondition
---@field IsSpotted fun(team: MissionTeam): MissionCondition

--- The dot-only builder chain returned by Spawn. Positions are map fractions
--- until real maps pin real coordinates; At is required — a chain without one fails the load.
---@class MissionSpawnChain
---@field At fun(fx: number, fz: number): MissionSpawnChain
---@field Named fun(name: MissionUnitName): MissionSpawnChain
---@field Grouped fun(group: MissionUnitGroup): MissionSpawnChain

--- One validated spawn entry, as Roster.Finalize returns it.
---@class MissionRosterEntry
---@field def UnitDefName
---@field team MissionTeamRole
---@field fx number map-fraction position, resolved against map size at spawn
---@field fz number
---@field name MissionUnitName|nil declared by Named
---@field group MissionUnitGroup|nil declared by Grouped

--- A registered trigger. Identity = source filename + declaration order,
--- stamped at registration — the unregister-by-identity key for hot reload.
---@class TriggerDescriptor
---@field id string "<filename>:<order>"
---@field filename string mission-relative trigger file path
---@field order integer 1-based declaration order within the file
---@field condition MissionCondition
---@field effects MissionEffect[] executed in Do order when the condition fires
---@field once boolean fire at most once (default true)
---@field delayFrames integer hold the effects until the conditions have held this long; 0 fires at once

--- The dot-only builder chain returned by When. There is no terminator: the
--- loader finalizes all chains when the file's include returns; a chain without a Do fails the load.
---@class TriggerChain
---@field When fun(condition: MissionCondition): TriggerChain another condition; all must hold
---@field After fun(seconds: MissionSeconds): TriggerChain hold the effects until the conditions have held that long
---@field Do fun(effect: MissionEffect): TriggerChain repeatable; effects run in Do order
---@field Once fun(once: boolean?): TriggerChain default true; pass false for repeating triggers

--- A unit-def reference produced by the injected UnitDef verb. Carries the
--- name only; resolution to an id happens where Spring exists.
---@class MissionUnitDefRef
---@field name UnitDefName

--- The injected Team.Player handle. Demo rule: resolves to the first human
--- team at mission load.
---@class MissionTeam
---@field teamID integer
---@field allyTeam integer
---@field Has fun(unitDef: MissionUnitDefRef, count: integer): MissionCondition

--- Serializable trigger progress: the pile a checkpoint saves. Definitions
--- reload from source; this table is reapplied on top.
---@class TriggerEngineState
---@field fired table<string, boolean> trigger id -> has fired
---@field heldSince table<string, integer> trigger id -> frame its conditions first held, for delays

--- What a required module's mission_dsl.lua returns. The loader composes the
--- sandbox env from the missions manifest's requires list — the dependency
--- list IS the vocabulary whitelist; a global collision is a load error.
---@class MissionDslFile
---@field filename string mission-relative trigger file path
---@field Register fun(descriptor: TriggerDescriptor)
---@field names table<string, boolean> roster unit names, for load-time validation
---@field groups table<string, boolean> roster group names, for load-time validation

---@class MissionDslContribution
---@field ForFile fun(file: MissionDslFile): { env: table<string, any>, Finalize: fun()|nil }
