require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, which the builder installs.
Builders.MissionApi.new():Install()

local totalUnitsBuilt = VFS.Include("luarules/mission_api/triggers/total_units_built.lua")

describe("mission_api.triggers.total_units_built", function()
	it("declares its type and parameters, and no callins", function()
		assert.are.equal("TotalUnitsBuilt", totalUnitsBuilt.type)

		local names, required = {}, {}
		for _, parameter in ipairs(totalUnitsBuilt.parameters) do
			names[parameter.name] = true
			if parameter.required then
				required[parameter.name] = true
			end
		end
		assert.is_true(names.teamID)
		assert.is_true(names.quantity)
		assert.is_true(names.unitDefName)
		assert.are.same({ teamID = true, quantity = true }, required)
		assert.is_nil(totalUnitsBuilt.callins)
	end)
end)
