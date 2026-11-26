local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local function loadLayouts(unitDefNames)
	local env = SpecEnv.new({
		UnitDefNames = unitDefNames,
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
		local layouts = loadLayouts({ armck_scav = {} })

		assert.equal(layouts.UnitGrids.armck[1][1][1] .. "_scav", layouts.UnitGrids.armck_scav[1][1][1])
		assert.equal(layouts.LabGrids.armlab[1] .. "_scav", layouts.LabGrids.armlab_scav[1])
	end)

	it("adds no scavenger layouts without scavenger unit defs", function()
		local layouts = loadLayouts({})

		assert.is_nil(layouts.UnitGrids.armck_scav)
		assert.is_nil(layouts.LabGrids.armlab_scav)
	end)
end)
