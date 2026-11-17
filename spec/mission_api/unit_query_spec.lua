local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local ARMFLEA, ARMPW = 7, 8
local unitDefIDs = { [100] = ARMFLEA, [101] = ARMPW }

-- unit_query captures this at its load.
local env = MissionSpecEnv.new({
	Spring = {
		GetUnitDefID = function(unitID)
			return unitDefIDs[unitID]
		end,
	},
})
MissionApiBuilder.new():Install(env)

local unitQuery = MissionSpecEnv.include(env, "luarules/mission_api/unit_query.lua")

describe("mission_api.unit_query", function()
	describe("DoesUnitMatch", function()
		it("rejects a unit of an excluded type and takes the others", function()
			local excluded = { [ARMFLEA] = true }
			assert.is_false(unitQuery.DoesUnitMatch(100, nil, nil, excluded))
			assert.is_true(unitQuery.DoesUnitMatch(101, nil, nil, excluded))
		end)
	end)
end)
