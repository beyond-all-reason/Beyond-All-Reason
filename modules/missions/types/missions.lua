--- Mission-runtime types: the trigger engine's descriptors and the authoring
--- DSL's chain/condition shapes. The DSL surface is dot-only: every chain step
--- is a plain call with parens, no colon methods, no metatables — mission files
--- must load identically in the synced sandbox (which strips rawset) and in
--- busted.

--- A condition the trigger engine evaluates on its cadence. Pure: reads only
--- the ctx it is handed; captures configuration (team ids, unit names), never
--- progress. Progress lives in the engine's state tables (the savegame rule).
---@class MissionCondition
---@field evaluate fun(ctx: MissionContext): boolean

--- What the engine hands every condition and effect. The gadget builds it from
--- Spring; specs build it from plain tables.
---@class MissionContext
---@field GetUnitDefCount fun(teamID: integer, unitDefName: string): integer count of finished units of that def
---@field frame integer current game frame

--- A registered trigger. Identity = source filename + declaration order,
--- stamped at registration — the unregister-by-identity key for hot reload.
---@class TriggerDescriptor
---@field id string "<filename>:<order>"
---@field filename string mission-relative trigger file path
---@field order integer 1-based declaration order within the file
---@field condition MissionCondition
---@field effect fun(ctx: MissionContext)
---@field once boolean fire at most once (default true)

--- The dot-only builder chain returned by T.When. Every step returns the
--- chain; Register is the terminal and returns nothing.
---@class TriggerChain
---@field Then fun(effect: fun(ctx: MissionContext)): TriggerChain
---@field Once fun(once: boolean?): TriggerChain default true; pass false for repeating triggers
---@field Register fun()

--- The `T` the loader injects into each trigger file's environment.
---@class TriggerDSL
---@field When fun(condition: MissionCondition): TriggerChain

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
