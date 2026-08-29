---@meta actions

--- Mission files must load identically in the synced sandbox (which strips
--- rawset) and in busted.

--- Alias names are LOAD-BEARING beyond the checker: the mission kit derives its
--- semantic model from them (alias -> slot semantic, literal unions -> editor enums).
---@alias UnitDefName string unit def name, e.g. "armpw"
---@alias ObjectiveName string
---@alias MissionTeamRole "player"|"enemy"|"gaia" spawn-time team role, resolved at arm
--- Wall-clock seconds, never frames. An alias so an editor can name the unit the
--- author is typing in; the DSL converts using the engine's own tick rate.
---@alias MissionSeconds number

---@class MissionCondition
---@field evaluate fun(ctx: MissionContext): boolean
---@field inputs string[]|nil events that can change this answer, each a member of a module's Events enum (missions/lib/events.lua, waves/lib/events.lua) or a forwarded callin; the loader refuses a name nothing raises. nil = poll every cadence

--- A
--- required module extends this class from its own types (`---@class
--- (partial) MissionContext`) with the functions its contribution's Context
--- supplies.
---@class (partial) MissionContext
---@field GetUnitDefCount fun(teamID: integer, unitDefName: string): integer count of finished units of that def
---@field IsObjectiveComplete fun(name: string): boolean
---@field frame integer current game frame

---@class MissionEffect
---@field execute fun(ctx: MissionContext)

--- Complete implies Reveal.
---@class MissionObjective
---@field Complete fun(): MissionEffect
---@field Reveal fun(): MissionEffect
---@field IsComplete fun(): MissionCondition

---@class TriggerDescriptor
---@field id string "<filename>:<order>"
---@field filename string mission-relative trigger file path
---@field order integer 1-based declaration order within the file
---@field condition MissionCondition
---@field effects MissionEffect[] executed in Do order when the condition fires
---@field limit integer|nil fires allowed (Once = 1, Times(n) = n); nil = unbounded
---@field delayFrames integer hold the effects until the conditions have held this long; 0 fires at once
---@field cooldownFrames integer floor between fires of a repeating trigger

---@class TriggerChain
---@field When fun(condition: MissionCondition): TriggerChain another condition; all must hold
---@field After fun(seconds: MissionSeconds): TriggerChain hold the effects until the conditions have held that long
---@field Do fun(effect: MissionEffect): TriggerChain repeatable; effects run in Do order
---@field Once fun(once: boolean?): TriggerChain default true; pass false for repeating triggers
---@field Times fun(count: integer): TriggerChain fire at most this many times
---@field Every fun(seconds: MissionSeconds): TriggerChain a repeating trigger's floor between fires

---@class MissionUnitDefRef
---@field name UnitDefName

---@class MissionTeam
---@field teamID integer
---@field allyTeam integer
---@field Has fun(unitDef: MissionUnitDefRef, count: integer): MissionCondition

---@class TriggerEngineState
---@field fired table<string, boolean> trigger id -> has fired
---@field heldSince table<string, integer> trigger id -> frame its conditions first held, for delays
---@field fires table<string, integer> trigger id -> how many times it has fired
---@field lastFired table<string, integer> trigger id -> frame of its last fire

---@class MissionDslFile
---@field filename string mission-relative trigger file path
---@field Register fun(descriptor: TriggerDescriptor)

---@class MissionProtectionLedger this mission's protect refcounts, persisted across a reload
---@field Get fun(unitID: integer): integer
---@field Set fun(unitID: integer, count: integer) zero forgets the unit

---@class MissionRuntime
---@field Protections MissionProtectionLedger
---@field Log fun(level: integer, message: string)

---@class MissionDslContribution
---@field ForFile fun(file: MissionDslFile): { env: table<string, any>, Finalize: fun()|nil }
---@field Context fun(runtime: MissionRuntime): table<string, function>|nil
---@field Events table<string, string>|nil an enum of the bus events this module raises
