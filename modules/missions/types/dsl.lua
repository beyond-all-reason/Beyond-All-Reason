---@meta dsl

--- The trigger-file authoring environment. These globals exist in no real
--- scope: mission_loader injects them into each triggers/*.lua sandbox (the
--- sandbox IS the API surface). This meta file mirrors that injection so the
--- language server sees what a trigger file sees.

---Start a trigger chain with its arming condition. Chain more conditions
---with .When(...), effects with .Do(...), behavior with .Once(...).
---@param condition MissionCondition
---@return TriggerChain
function When(condition) end

---Objective handle: .Complete() builds the effect side, .IsComplete() the
---condition side.
---@param name ObjectiveName
---@return MissionObjective
function Objective(name) end

---Unit-def reference by name; resolution to an id happens where Spring exists.
---@param name UnitDefName
---@return MissionUnitDefRef
function UnitDef(name) end

---Named-unit reference: the condition side of one unit the mission's
---units.lua roster spawned. Validated against the roster at load — an
---unknown name is a load error, not a silent never-true condition.
---@param name MissionUnitName
---@return MissionUnitRef
function Unit(name) end

---Declare one unit of the mission's opening world state. units.lua sandbox
---only — not injected into trigger files. Chain .At(fx, fz) (required, map
---fractions), .Named(name), .Grouped(group).
---@param unitDef MissionUnitDefRef
---@param team MissionTeamRole
---@return MissionSpawnChain
function Spawn(unitDef, team) end

---@type { Player: MissionTeam }
Team = {}

---@type MissionUnits
Units = {}

---@type MissionCombat
Combat = {}

---@type MissionMatchFlow
MatchFlow = {}
