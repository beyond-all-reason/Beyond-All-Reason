require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/features/create_features.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local missionApi = GG["MissionAPI"]

describe("mission_api.actions.create_features", function()

	before_each(function()
		Builders.MissionApi.new():Install()
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "CreateFeatures",
			featureLoadout = "FeatureLoadout!",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("calls Loadout.SpawnFeatureLoadout with the given loadout", function()
			local loadout = { { featureDefName = "rock", x = 0, z = 0 } }
			action.actionFunction(loadout)
			assert.are.equal(1, #missionApi.calls.spawnFeatureLoadout)
			assert.are.same(loadout, missionApi.calls.spawnFeatureLoadout[1].loadout)
		end)
	end)

end)
