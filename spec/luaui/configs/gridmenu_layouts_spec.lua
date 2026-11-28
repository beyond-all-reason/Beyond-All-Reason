local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local function loadLayouts(unitDefs)
	local env = SpecEnv.new({
		UnitDefs = unitDefs,
		Spring = {
			GetModOptions = function()
				return {}
			end,
		},
	})

	return SpecEnv.include(env, "luaui/configs/gridmenu_layouts.lua")
end

describe("gridmenu_layouts scavenger variants", function()
	it("copies builder and lab layouts when scavenger unit defs exist", function()
		local layouts = loadLayouts({ { name = "armck_scav", customParams = { isscavenger = "1" } } })

		assert.equal(layouts.UnitGrids.armck[1][1][1] .. "_scav", layouts.UnitGrids.armck_scav[1][1][1])
		assert.equal(layouts.LabGrids.armlab[1] .. "_scav", layouts.LabGrids.armlab_scav[1])
	end)

	it("adds no scavenger layouts without scavenger unit defs", function()
		local layouts = loadLayouts({ { name = "armck", customParams = {} } })

		assert.is_nil(layouts.UnitGrids.armck_scav)
		assert.is_nil(layouts.LabGrids.armlab_scav)
	end)
end)
