local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local totalUnitsKilled = VFS.Include("luarules/mission_api/conditions/total_units_killed.lua")

describe("mission_api.conditions.total_units_killed", function()
	it("declares its type, kind and parameters, and no callins", function()
		assert.are.equal("TotalUnitsKilled", totalUnitsKilled.type)
		assert.are.equal("event", totalUnitsKilled.kind)

		local names, required = {}, {}
		for _, parameter in ipairs(totalUnitsKilled.parameters) do
			names[parameter.name] = true
			if parameter.required then
				required[parameter.name] = true
			end
		end
		assert.is_true(names.teamID)
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.are.same({ teamID = true }, required)
		assert.is_nil(totalUnitsKilled.callins)
	end)
end)
