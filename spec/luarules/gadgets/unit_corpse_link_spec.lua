local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local GADGET_PATH = "luarules/gadgets/unit_corpse_link.lua"
local COMMANDER_DEF_ID = 1
local WRECK_DEF_ID = 10
local HEAP_DEF_ID = 11

local DYING_COMMANDER = 1
local ITS_OWN_WRECK = 20
local ITS_OWN_HEAP = 21
local OLDER_WRECK = 30
local HEAP_OF_OLDER_WRECK = 31

local function loadGadget(world)
	local env = SpecEnv.new({
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
		},
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
	local world ---@type table
	local gadget ---@type table
	local getCorpsePriorUnitID ---@type fun(featureID: integer): integer?

	before_each(function()
		world = { units = { [DYING_COMMANDER] = { x = 100, z = 100 } }, features = {} }
		gadget, getCorpsePriorUnitID = loadGadget(world)
		gadget:UnitDestroyed(DYING_COMMANDER, COMMANDER_DEF_ID)
	end)

	it("links a wreck to the unit that died there", function()
		world.features[ITS_OWN_WRECK] = { defID = WRECK_DEF_ID, x = 102, z = 101 }

		assert.equal(DYING_COMMANDER, getCorpsePriorUnitID(ITS_OWN_WRECK))
	end)

	it("links a heap to the unit that died there when no wreck came first", function()
		world.features[ITS_OWN_HEAP] = { defID = HEAP_DEF_ID, x = 100, z = 100 }

		assert.equal(DYING_COMMANDER, getCorpsePriorUnitID(ITS_OWN_HEAP))
	end)

	it("leaves the link for the dying unit's own wreck when a heap replaces another wreck", function()
		world.features[OLDER_WRECK] = { defID = WRECK_DEF_ID, x = 300, z = 300 }
		world.features[HEAP_OF_OLDER_WRECK] = { defID = HEAP_DEF_ID, x = 300, z = 300 }

		assert.is_nil(getCorpsePriorUnitID(HEAP_OF_OLDER_WRECK))

		world.features[ITS_OWN_WRECK] = { defID = WRECK_DEF_ID, x = 100, z = 100 }

		assert.equal(DYING_COMMANDER, getCorpsePriorUnitID(ITS_OWN_WRECK))
	end)
end)
