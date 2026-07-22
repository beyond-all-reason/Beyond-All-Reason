--- Mission-runtime types: the trigger engine's descriptors and the authoring
--- DSL's chain/condition/effect shapes. The DSL surface is dot-only AND
--- closure-free: every chain step is a plain call with parens, no colon
--- methods, no metatables, and no function bodies in mission files — effects
--- are lazy objects built by named verbs. Mission files must load identically
--- in the synced sandbox (which strips rawset) and in busted.

--- A condition is not a bare predicate — it carries metadata about what can
--- change its answer (mission_authoring_dsl.md, "Conditions declare their
--- inputs"). Inputs name events on the mission bus: engine callins are one
--- producer ("UnitFinished"), modules are another ("mission.objective_changed").
--- nil inputs = poll every cadence — the fallback stays.
--- Pure: reads only the ctx it is handed; captures configuration (team ids,
--- unit names), never progress. Progress lives in the engine's state tables;
--- inputs are configuration, dirty flags are derived (the savegame rule).
---@class MissionCondition
---@field evaluate fun(ctx: MissionContext): boolean
---@field inputs string[]|nil events that can change this answer; nil = poll every cadence

--- What the engine hands every condition and effect. The gadget builds it from
--- Spring; specs build it from plain tables.
---@class MissionContext
---@field GetUnitDefCount fun(teamID: integer, unitDefName: string): integer count of finished units of that def
---@field IsObjectiveComplete fun(name: string): boolean
---@field frame integer current game frame

--- A lazy effect built by a named verb (Objective("x").Complete(),
--- MatchFlow.Victory(Team.Player)). The engine executes it when the trigger's
--- condition fires. Like conditions, effects capture configuration only —
--- never progress, and never author-written function bodies.
---@class MissionEffect
---@field execute fun(ctx: MissionContext)

--- The injected Objective verb's handle: Complete() builds the effect side,
--- IsComplete() the condition side — victory triggers watch objective state
--- rather than living inside the objective's own trigger.
---@class MissionObjective
---@field Complete fun(): MissionEffect
---@field IsComplete fun(): MissionCondition

--- The injected MatchFlow verbs: lazy mirrors of the matchflow module api.
--- They take the Team handle so mission lines read as English.
---@class MissionMatchFlow
---@field Victory fun(team: MissionTeam): MissionEffect
---@field Defeat fun(team: MissionTeam): MissionEffect

--- A registered trigger. Identity = source filename + declaration order,
--- stamped at registration — the unregister-by-identity key for hot reload.
---@class TriggerDescriptor
---@field id string "<filename>:<order>"
---@field filename string mission-relative trigger file path
---@field order integer 1-based declaration order within the file
---@field condition MissionCondition
---@field effects MissionEffect[] executed in Do order when the condition fires
---@field once boolean fire at most once (default true)

--- The dot-only builder chain returned by When. Every step returns the
--- chain. There is no terminator: the loader finalizes all chains when the
--- file's include returns, and a chain without a Do fails the load.
---@class TriggerChain
---@field When fun(condition: MissionCondition): TriggerChain another condition; all must hold
---@field Do fun(effect: MissionEffect): TriggerChain repeatable; effects run in Do order
---@field Once fun(once: boolean?): TriggerChain default true; pass false for repeating triggers

--- A unit-def reference produced by the injected UnitDef verb. Carries the
--- name only; resolution to an id happens where Spring exists.
---@class MissionUnitDefRef
---@field name string

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
