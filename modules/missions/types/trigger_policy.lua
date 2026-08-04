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

---Objective handle: .Complete() and .Reveal() build the effect side,
---.IsComplete() the condition side. Reveal marks the objective relevant so
---the tracker widget draws it; Complete implies Reveal.
---
---In objectives.lua — the mission's definition site, sibling of units.lua —
---the same verb starts a declaration instead (MissionObjectiveDeclaration:
---.Title/.CompletedWhen/.When/.RevealedWhen/.Foreshadow). When that file
---exists, an id no declaration backs is a load error here, the same
---contract Unit has with the roster.
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
---fractions), .Named(name), .Grouped(group), .Neutral().
---@param unitDef MissionUnitDefRef
---@param team MissionTeamRole
---@return MissionSpawnChain
function Spawn(unitDef, team) end

---Take a unit the team already owns instead of adding another, and give it a
---mission name. units.lua sandbox only. Chain .Named(name), .Grouped(group)
---and .OrSpawnAt(fx, fz) (required — it says where to build one when the team
---turns out to have none).
---@param unitDef MissionUnitDefRef
---@param team MissionTeamRole
---@return MissionClaimChain
function Claim(unitDef, team) end

---@type { Player: MissionTeam }
Team = {}
