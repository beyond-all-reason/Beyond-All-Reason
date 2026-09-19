require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local unitsOwned = VFS.Include("luarules/mission_api/triggers/units_owned.lua")

describe("mission_api.triggers.units_owned", function()
	it("declares its type and parameters, and no callins", function()
		assert.are.equal("UnitsOwned", unitsOwned.type)

		local names, required = {}, {}
		for _, parameter in ipairs(unitsOwned.parameters) do
			names[parameter.name] = true
			if parameter.required then
				required[parameter.name] = true
			end
		end
		assert.is_true(names.teamID)
		assert.is_true(names.quantity)
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.are.same({ teamID = true, quantity = true }, required)
		assert.is_nil(unitsOwned.callins)
	end)
end)
