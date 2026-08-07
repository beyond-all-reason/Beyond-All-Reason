---@meta policy trigger

--- The trigger-file authoring environment: the statements and handles only
--- a mission speaks. Actions a module can perform live in its own
--- types/actions.lua, where every grammar can read them.
---
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

---@type { Player: MissionTeam }
Team = {}

---@type MissionMatchFlow
MatchFlow = {}
