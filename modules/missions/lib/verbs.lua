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

return Verbs
