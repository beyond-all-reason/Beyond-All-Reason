local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local GADGET_PATH = "luarules/gadgets/unit_corpse_link.lua"
local COMMANDER_DEF_ID = 1
local WRECK_DEF_ID = 10
local HEAP_DEF_ID = 11

local function loadGadget(world)
	local env = SpecEnv.new({
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
		},
		Engine = { FeatureSupport = {} },
		Game = { gameSpeed = 30 },
		UnitDefNames = { armcom = { id = COMMANDER_DEF_ID } },
		FeatureDefs = {
			[WRECK_DEF_ID] = { customParams = { fromunit = "armcom" } },
			[HEAP_DEF_ID] = { customParams = { fromunit = "armcom" } },
		},
		Spring = {
			GetGameFrame = function()
				return 0
			end,
			GetUnitPosition = function(unitID)
				local unit = world.units[unitID]
				return unit.x, 0, unit.z
			end,
			GetFeatureDefID = function(featureID)
				return world.features[featureID].defID
			end,
			GetFeaturePosition = function(featureID)
				local feature = world.features[featureID]
				return feature.x, 0, feature.z
			end,
			GetFeatureResurrect = function() end,
			GetFeaturesInCylinder = function(x, z, radius)
				local found = {}
				for featureID, feature in pairs(world.features) do
					if math.abs(feature.x - x) <= radius and math.abs(feature.z - z) <= radius then
						found[#found + 1] = featureID
					end
				end
				return found
			end,
		},
	})
	SpecEnv.include(env, GADGET_PATH)
	env.gadget:Initialize()
	return env.gadget, env.GG.GetCorpsePriorUnitID
end

describe("unit_corpse_link", function()
	local world, gadget, getCorpsePriorUnitID

	before_each(function()
		world = { units = { [1] = { x = 100, z = 100 } }, features = {} }
		gadget, getCorpsePriorUnitID = loadGadget(world)
		gadget:UnitDestroyed(1, COMMANDER_DEF_ID)
	end)

	it("links a wreck to the unit that died there", function()
		world.features[20] = { defID = WRECK_DEF_ID, x = 102, z = 101 }

		assert.equal(1, getCorpsePriorUnitID(20))
	end)

	it("links a heap to the unit that died there when no wreck came first", function()
		world.features[20] = { defID = HEAP_DEF_ID, x = 100, z = 100 }

		assert.equal(1, getCorpsePriorUnitID(20))
	end)

	it("leaves the link for the dying unit's own wreck when a heap replaces another wreck", function()
		world.features[30] = { defID = WRECK_DEF_ID, x = 300, z = 300 }
		world.features[31] = { defID = HEAP_DEF_ID, x = 300, z = 300 }

		assert.is_nil(getCorpsePriorUnitID(31))

		world.features[20] = { defID = WRECK_DEF_ID, x = 100, z = 100 }

		assert.equal(1, getCorpsePriorUnitID(20))
	end)
end)
