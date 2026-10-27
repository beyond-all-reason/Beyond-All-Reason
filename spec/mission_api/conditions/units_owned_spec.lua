local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local unitsOwned = VFS.Include("luarules/mission_api/conditions/units_owned.lua")

describe("mission_api.conditions.units_owned", function()
	it("declares its type, kind and parameters, and no callins", function()
		assert.are.equal("UnitsOwned", unitsOwned.type)
		assert.are.equal("metric", unitsOwned.kind)

		local names, required = {}, {}
		for _, parameter in ipairs(unitsOwned.parameters) do
			names[parameter.name] = true
			if parameter.required then
				required[parameter.name] = true
			end
		end
		assert.is_true(names.teamID)
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.are.same({ teamID = true }, required)
		assert.is_nil(unitsOwned.callins)
	end)
end)
