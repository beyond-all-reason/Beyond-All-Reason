
local Verbs = {}

---@param name string unit def name, e.g. "armpw"
---@return MissionUnitDefRef
function Verbs.UnitDef(name)
	assert(type(name) == "string", "UnitDef expects a unit def name string")
	return { name = name }
end

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
		assert(type(unitDef) == "table" and type(unitDef.name) == "string", "Team.Has expects a UnitDef(...) reference")
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

---@param name MissionUnitName|fun(): MissionUnitName the name, or how to read it once known
---@return MissionUnitRef
function Verbs.UnitRef(name)
	local function resolved()
		local value = type(name) == "function" and name() or name
		assert(type(value) == "string", "a roster handle was referenced before it was named")
		return value
	end
	return {
		name = type(name) == "string" and name or nil,
		---@return MissionCondition
		IsDestroyed = function()
			return {
				inputs = { "UnitDestroyed" },
				---@param ctx MissionContext
				evaluate = function(ctx)
					return ctx.IsUnitDestroyed(resolved())
				end,
			}
		end,
		---@param team MissionTeam
		---@return MissionCondition
		IsSpotted = function(team)
			assert(
				type(team) == "table" and type(team.allyTeam) == "number",
				"Unit.IsSpotted expects a Team handle (e.g. Team.Player)"
			)
			return {
				inputs = { "UnitEnteredLos" },
				---@param ctx MissionContext
				evaluate = function(ctx)
					return ctx.IsUnitSpotted(resolved(), team.allyTeam)
				end,
			}
		end,
	}
end

---@param names table<string, boolean> the roster's declared unit names
---@return fun(name: MissionUnitName): MissionUnitRef
function Verbs.MakeUnit(names)
	return function(name)
		assert(type(name) == "string", "Unit expects a mission unit name string")
		assert(
			names[name],
			'Unit("' .. name .. "\"): no such unit — units.lua Named(...) declares the mission's unit names"
		)
		return Verbs.UnitRef(name)
	end
end

return Verbs
