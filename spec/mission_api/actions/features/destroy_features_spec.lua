local SpringSyncedBuilder = VFS.Include("spec/builders/spring_synced_builder.lua")
local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/features/destroy_features.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

---Track the given `name -> featureID` pairs, and mark those IDs valid.
local function seedFeatures(name, ...)
	local missionApi = MissionApiBuilder.new()
	local spring = SpringSyncedBuilder.new()
	for _, featureID in ipairs({ ... }) do
		missionApi:WithTrackedFeature(name, featureID)
		spring:WithValidFeature(featureID)
	end
	missionApi:Install()
	env.Spring = spring:Build()
	return env.Spring.calls.destroyFeature
end

describe("mission_api.actions.destroy_features", function()

	local destroyFeatureCalls

	before_each(function()
		MissionApiBuilder.new():Install()
		env.Spring = SpringSyncedBuilder.new():Build()
		destroyFeatureCalls = env.Spring.calls.destroyFeature
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "DestroyFeatures",
			featureName = "FeatureName!",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("is a no-op for an untracked feature name", function()
			action.actionFunction("unknown")
			assert.are.equal(0, #destroyFeatureCalls)
		end)

		it("destroys valid tracked features", function()
			destroyFeatureCalls = seedFeatures("rock", 10, 11)
			action.actionFunction("rock")
			assert.are.equal(2, #destroyFeatureCalls)
		end)

		it("skips invalid feature IDs", function()
			-- tracked, but never marked valid
			MissionApiBuilder.new():WithTrackedFeature("rock", 10):Install()
			env.Spring = SpringSyncedBuilder.new():Build()

			action.actionFunction("rock")

			assert.are.equal(0, #env.Spring.calls.destroyFeature)
		end)

		it("only destroys features matching the given name", function()
			MissionApiBuilder.new():WithTrackedFeature("rock", 10):WithTrackedFeature("tree", 20):Install()
			env.Spring = SpringSyncedBuilder.new():WithValidFeature(10):WithValidFeature(20):Build()

			action.actionFunction("rock")

			assert.are.equal(1, #env.Spring.calls.destroyFeature)
			assert.are.equal(10, env.Spring.calls.destroyFeature[1])
		end)
	end)

end)
