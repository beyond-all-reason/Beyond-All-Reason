--- The three demo verbs' pure halves: UnitDef refs and the Team handle with
--- its Has condition. No Spring here — conditions read counts from the ctx the
--- engine is handed, so this specs under busted; the gadget supplies a ctx
--- backed by Spring.GetTeamUnitDefCount.
---
--- Conditions capture configuration only (team id, unit name, threshold) —
--- never progress. Dot-only surface, same rule as the chain DSL.

local Verbs = {}

---@param name string unit def name, e.g. "armpw"
---@return MissionUnitDefRef
function Verbs.UnitDef(name)
	assert(type(name) == "string", "UnitDef expects a unit def name string")
	return { name = name }
end

---Build a Team handle for one team.
---@param teamID integer
---@param allyTeam integer
---@return MissionTeam
function Verbs.MakeTeam(teamID, allyTeam)
	local team = {
		teamID = teamID,
		allyTeam = allyTeam,
	}

	---@param unitDef MissionUnitDefRef
	---@param count integer
	---@return MissionCondition
	team.Has = function(unitDef, count)
		assert(type(unitDef) == "table" and type(unitDef.name) == "string",
			"Team.Has expects a UnitDef(...) reference")
		assert(type(count) == "number", "Team.Has expects a count")
		return {
			---@param ctx MissionContext
			evaluate = function(ctx)
				return ctx.GetUnitDefCount(teamID, unitDef.name) >= count
			end,
		}
	end

	return team
end

return Verbs
