-- Pregame builders need real engine command queues, but no gameplay lifecycle.
-- Keep engine events and LuaUI intact; only the LuaRules router uses this filter.
local M = {}

function M.new(spring)
	local units = {}
	local pending
	local api = {}

	function api.create(defID, x, y, z, facing, teamID, beingBuilt, flatten, unitID)
		assert(spring.GetGameFrame() <= 0, "Pregame units cannot be created during play")
		assert(not pending, "Nested pregame unit creation")
		pending = { defID = defID, teamID = teamID, unitID = unitID }
		-- UnitCreated runs inside CreateUnit. Restore the context even on failure.
		local ok, result = pcall(spring.CreateUnit, defID, x, y, z, facing, teamID, beingBuilt, flatten, unitID)
		pending = nil
		if not ok then
			error(result, 0)
		end
		return result
	end

	function api.created(unitID, defID, teamID)
		if
			pending
			and pending.defID == defID
			and pending.teamID == teamID
			and (not pending.unitID or pending.unitID == unitID)
		then
			pending = nil
			units[unitID] = true
			-- Publish before any LuaRules/LuaUI consumer sees the new unit.
			spring.SetUnitRulesParam(unitID, "pregame_proxy", 1, { public = true })
			return true
		end
		-- A real commander may deliberately reuse the removed proxy's ID.
		units[unitID] = nil
		return false
	end

	function api.contains(unitID)
		return units[unitID] == true
	end

	function api.destroyed(unitID)
		local proxy = units[unitID]
		units[unitID] = nil
		return proxy == true
	end

	return api
end

return M
