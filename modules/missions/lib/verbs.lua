--- The mission verbs' pure halves: UnitDef refs, the Team handle with its Has
--- condition, the Unit noun over roster-named units, group verbs, and the
--- Combat sugar. No Spring here — conditions read from and effects act through
--- the ctx the engine is handed, so this specs under busted; the gadget
--- supplies a ctx backed by Spring.
---
--- Conditions and effects capture configuration only (team id, unit name,
--- threshold) — never progress. Dot-only surface, same rule as the chain DSL.

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
			-- Transfers move counts too, hence Given/Taken.
			inputs = { "UnitFinished", "UnitDestroyed", "UnitGiven", "UnitTaken" },
			---@param ctx MissionContext
			evaluate = function(ctx)
				return ctx.GetUnitDefCount(teamID, unitDef.name) >= count
			end,
		}
	end

	return team
end

---Named-unit reference: the condition side of one roster unit. The name is
---bound to a spawned unit by the mission's units.lua; resolution happens in
---ctx where Spring exists. Both conditions read latched state — "has been
---destroyed/spotted", not "is right now" — so they hold once true.
---@param name string
---@return MissionUnitRef
function Verbs.Unit(name)
	assert(type(name) == "string", "Unit expects a mission unit name string")
	return {
		name = name,
		---@return MissionCondition
		IsDestroyed = function()
			return {
				inputs = { "UnitDestroyed" },
				---@param ctx MissionContext
				evaluate = function(ctx)
					return ctx.IsUnitDestroyed(name)
				end,
			}
		end,
		---@param team MissionTeam
		---@return MissionCondition
		IsSpotted = function(team)
			assert(type(team) == "table" and type(team.allyTeam) == "number",
				"Unit.IsSpotted expects a Team handle (e.g. Team.Player)")
			return {
				inputs = { "UnitEnteredLos" },
				---@param ctx MissionContext
				evaluate = function(ctx)
					return ctx.IsUnitSpotted(name, team.allyTeam)
				end,
			}
		end,
	}
end

---Group verbs over roster-named groups.
---@type MissionUnits
Verbs.Units = {
	---@param group string
	---@param team MissionTeam
	---@return MissionEffect
	Transfer = function(group, team)
		assert(type(group) == "string", "Units.Transfer expects a group name string")
		assert(type(team) == "table" and type(team.teamID) == "number",
			"Units.Transfer expects a Team handle (e.g. Team.Player)")
		return {
			---@param ctx MissionContext
			execute = function(ctx)
				ctx.TransferGroup(group, team.teamID)
			end,
		}
	end,
}

---Build one trigger file's Combat verbs. Protect is a plain effect; its
---.Until(condition) sugar bounds the protection's lifetime by recording a
---companion into `untils` — the loader registers it as the literal desugared
---statement When(condition).Do(Combat.Unprotect(unit)).
---@param untils { unit: MissionUnitRef, condition: MissionCondition }[] loader-owned, drained after Finalize
---@return MissionCombat
function Verbs.MakeCombat(untils)
	---@param unitRef MissionUnitRef
	---@param verb string
	local function checkUnitRef(unitRef, verb)
		assert(type(unitRef) == "table" and type(unitRef.name) == "string",
			verb .. " expects a Unit(...) reference")
	end

	local combat = {}

	---@param unitRef MissionUnitRef
	---@return MissionProtectEffect
	combat.Protect = function(unitRef)
		checkUnitRef(unitRef, "Combat.Protect")
		---@param ctx MissionContext
		local execute = function(ctx)
			ctx.Protect(unitRef.name)
		end
		return {
			execute = execute,
			---@param condition MissionCondition
			---@return MissionEffect
			Until = function(condition)
				assert(type(condition) == "table" and type(condition.evaluate) == "function",
					"Combat.Protect(...).Until expects a condition")
				untils[#untils + 1] = { unit = unitRef, condition = condition }
				return { execute = execute }
			end,
		}
	end

	---@param unitRef MissionUnitRef
	---@return MissionEffect
	combat.Unprotect = function(unitRef)
		checkUnitRef(unitRef, "Combat.Unprotect")
		return {
			---@param ctx MissionContext
			execute = function(ctx)
				ctx.Unprotect(unitRef.name)
			end,
		}
	end

	return combat
end

return Verbs
