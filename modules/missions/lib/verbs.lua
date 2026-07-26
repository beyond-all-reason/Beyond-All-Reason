--- Mission verbs' pure halves. No Spring here, so this specs under busted;
--- conditions/effects capture configuration only, never progress.

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

---Build the Unit noun over the roster: unknown name is a LOAD error, not a
---silently-never-true condition. IsDestroyed/IsSpotted read latched state.
---@param names table<string, boolean> the roster's declared unit names
---@return fun(name: MissionUnitName): MissionUnitRef
function Verbs.MakeUnit(names)
	return function(name)
		assert(type(name) == "string", "Unit expects a mission unit name string")
		assert(names[name],
			'Unit("' .. name .. '"): no such unit — units.lua Named(...) declares the mission\'s unit names')
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
end

---Build the Units group verbs over one mission's roster; group references
---are validated like unit names (declared in units.lua Grouped(...), only).
---@param groups table<string, boolean> the roster's declared group names
---@return MissionUnits
function Verbs.MakeUnits(groups)
	return {
		---@param group MissionUnitGroup
		---@param team MissionTeam
		---@return MissionEffect
		Transfer = function(group, team)
			assert(type(group) == "string", "Units.Transfer expects a group name string")
			assert(groups[group],
				'Units.Transfer("' .. group .. '"): no such group — units.lua Grouped(...) declares the mission\'s groups')
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
end

---Build one trigger file's Combat verbs. .Until(condition) records a
---companion into `untils`, desugared by the loader as When(condition).Do(Combat.Unprotect(unit)).
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
