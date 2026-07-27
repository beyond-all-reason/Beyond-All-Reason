---@meta policy trigger

--- These globals exist in no real scope: mission_loader injects them into each triggers/*.lua sandbox;
--- this meta file mirrors that injection so the language server sees what a trigger file sees.

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

---@type { Player: MissionTeam }
Team = {}

---@type MissionMatchFlow
MatchFlow = {}

---Declare a typed slot. variables.lua sandbox only. Chain .Number(default),
---.Boolean(default) or .String(default); the handle then offers .Is/.AtLeast/
---.AtMost (conditions) and .Set/.Add (effects).
---@param name string
---@return MissionVariableChain
function Variable(name) end
