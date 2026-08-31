---@meta policy trigger

--- These globals exist in no real scope: mission_loader injects them into each triggers/*.lua sandbox.

---@param condition MissionCondition
---@return TriggerChain
function When(condition) end

---@param name ObjectiveName
---@return MissionObjective
function Objective(name) end

---@param name UnitDefName
---@return MissionUnitDefRef
function UnitDef(name) end

---@param name MissionUnitName
---@return MissionUnitRef
function Unit(name) end

---@param unitDef MissionUnitDefRef
---@param team MissionTeamRole
---@return MissionSpawnChain
function Spawn(unitDef, team) end

---@param unitDef MissionUnitDefRef
---@param team MissionTeamRole
---@return MissionClaimChain
function Claim(unitDef, team) end

---@type { Player: MissionTeam }
Team = {}

---@type MissionMatchFlow
MatchFlow = {}

---@param name MissionUnitGroup
---@return MissionGroupRef
function Group(name) end

---@param name string
---@return MissionVariableChain
function Variable(name) end
