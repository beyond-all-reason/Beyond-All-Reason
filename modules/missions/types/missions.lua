---@meta actions

--- Mission files must load identically in the synced sandbox (which strips
--- rawset) and in busted.

--- Alias names are LOAD-BEARING beyond the checker: the mission kit derives its
--- semantic model from them (alias -> slot semantic, literal unions -> editor enums).
---@alias UnitDefName string unit def name, e.g. "armpw"
---@alias MissionUnitName string roster unit name, declared by units.lua Named(...)
---@alias MissionUnitGroup string roster group name, declared by units.lua Grouped(...)
---@alias ObjectiveName string
---@alias MissionTeamRole "player"|"enemy"|"gaia" spawn-time team role, resolved at arm
--- Wall-clock seconds, never frames. An alias so an editor can name the unit the
--- author is typing in; the DSL converts using the engine's own tick rate.
---@alias MissionSeconds number

---@class MissionCondition
---@field evaluate fun(ctx: MissionContext): boolean
---@field inputs string[]|nil events that can change this answer, each a member of a module's Events enum (missions/lib/events.lua, waves/lib/events.lua) or a forwarded callin; the loader refuses a name nothing raises. nil = poll every cadence

---@class (partial) MissionContext
---@field GetUnitDefCount fun(teamID: integer, unitDefName: string): integer count of finished units of that def
---@field IsObjectiveComplete fun(name: string): boolean
---@field GetVariable fun(name: string): number|boolean|string|nil
---@field SetVariable fun(name: string, value: number|boolean|string)
---@field IsUnitDestroyed fun(name: string): boolean
---@field IsUnitSpotted fun(name: string, allyTeamID: integer): boolean
---@field frame integer current game frame

---@class MissionEffect
---@field execute fun(ctx: MissionContext)

---@class MissionObjective
---@field Complete fun(): MissionEffect
---@field Reveal fun(): MissionEffect
---@field IsComplete fun(): MissionCondition
---@field Title fun(title: string): MissionObjectiveDeclaration objectives.lua sandbox only
---@field CompletedWhen fun(condition: MissionCondition): MissionObjectiveDeclaration objectives.lua sandbox only
---@field RevealedWhen fun(condition: MissionCondition): MissionObjectiveDeclaration objectives.lua sandbox only
---@field Foreshadow fun(): MissionObjectiveDeclaration objectives.lua sandbox only

---@class MissionObjectiveDeclaration
---@field id string the objective's id, the wire identity
---@field Title fun(title: string): MissionObjectiveDeclaration display wording; defaults to the id with underscores as spaces
---@field CompletedWhen fun(condition: MissionCondition): MissionObjectiveDeclaration one way to complete; a second CompletedWhen is another way (OR), each compiling to its own trigger
---@field When fun(condition: MissionCondition): MissionObjectiveDeclaration a gate on the whole objective: every way to complete must also find it true; position-free, as on a trigger
---@field RevealedWhen fun(condition: MissionCondition): MissionObjectiveDeclaration replace the default reveal cadence with the mission's own moment
---@field Foreshadow fun(): MissionObjectiveDeclaration draw the line greyed-out before its reveal
---@field IsComplete fun(): MissionCondition
---@field Complete fun(): MissionEffect the effect side, for the files that include this one
---@field Reveal fun(): MissionEffect

---@class MissionObjectiveDeclarationEntry
---@field id string
---@field title string
---@field completions MissionCondition[][] disjuncts (one per CompletedWhen), each compiling to its own derived trigger; empty = a standing objective, transparent to the reveal cadence
---@field gates MissionCondition[] the When conditions, ANDed onto every disjunct
---@field revealedWhen MissionCondition|nil set by RevealedWhen
---@field revealAtArm boolean|nil marked by the loader: no declared moment, no completable predecessor
---@field foreshadow boolean

---@class MissionUnitRef
---@field name MissionUnitName
---@field IsDestroyed fun(): MissionCondition
---@field IsSpotted fun(team: MissionTeam): MissionCondition

--- Positions are map fractions until real maps pin real coordinates; a chain
--- without At fails the load.
---@class MissionSpawnChain
---@field At fun(fx: number, fz: number): MissionSpawnChain
---@field Named fun(name: MissionUnitName): MissionSpawnChain
---@field Grouped fun(group: MissionUnitGroup|MissionGroupRef): MissionSpawnChain
---@field Neutral fun(): MissionSpawnChain starts inert: neither shoots nor is shot at, until handed over
---@field IsSpotted fun(team: MissionTeam): MissionCondition the handle is also the reference
---@field IsDestroyed fun(): MissionCondition
---@field name MissionUnitName? set once the file is loaded: Named, or the export key

---@class MissionClaimChain
---@field Named fun(name: MissionUnitName): MissionClaimChain
---@field Grouped fun(group: MissionUnitGroup|MissionGroupRef): MissionClaimChain
---@field OrSpawnAt fun(fx: number, fz: number): MissionClaimChain
---@field IsSpotted fun(team: MissionTeam): MissionCondition
---@field IsDestroyed fun(): MissionCondition
---@field name MissionUnitName? set once the file is loaded: Named, or the export key

---@class MissionRosterEntry
---@field def UnitDefName
---@field team MissionTeamRole
---@field fx number map-fraction position, resolved against map size at spawn
---@field fz number
---@field name MissionUnitName|nil declared by Named
---@field group MissionUnitGroup|nil declared by Grouped
---@field claim boolean|nil written by Claim: bind to an existing unit if the team has one
---@field neutral boolean|nil written by Neutral: spawn inert, cleared when the unit changes hands

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
---@field names table<string, boolean> roster unit names, for load-time validation
---@field groups table<string, boolean> roster group names, for load-time validation

---@class MissionProtectionLedger this mission's protect refcounts, persisted across a reload
---@field Get fun(unitID: integer): integer
---@field Set fun(unitID: integer, count: integer) zero forgets the unit

---@class MissionRuntime
---@field UnitOf fun(name: string): integer|nil the living unit a roster name binds to
---@field GroupUnits fun(groupName: string): integer[]|nil
---@field ReleaseHoldFire fun(unitID: integer) a spawned-Neutral unit holds fire until whoever moves it says otherwise
---@field Protections MissionProtectionLedger
---@field Log fun(level: integer, message: string)

---@class MissionDslContribution
---@field ForFile fun(file: MissionDslFile): { env: table<string, any>, Finalize: fun()|nil }
---@field Context fun(runtime: MissionRuntime): table<string, function>|nil
---@field Events table<string, string>|nil an enum of the bus events this module raises

---@class MissionGroupRef
---@field group MissionUnitGroup

---@class MissionVariableChain
---@field Number fun(default: number): MissionVariableChain
---@field Boolean fun(default: boolean): MissionVariableChain
---@field String fun(default: string): MissionVariableChain
---@field Is fun(value: number|boolean|string): MissionCondition
---@field AtLeast fun(n: number): MissionCondition
---@field AtMost fun(n: number): MissionCondition
---@field Set fun(value: number|boolean|string): MissionEffect
---@field Add fun(n: number): MissionEffect

---@class MissionVariableEntry
---@field name string
---@field kind "number"|"boolean"|"string"
---@field default number|boolean|string
