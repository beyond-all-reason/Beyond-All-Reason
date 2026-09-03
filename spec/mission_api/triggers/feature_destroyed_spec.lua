require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and FeatureDefs inside its handler.
Builders.MissionApi.new():Install()

local featureDefs = Builders.FeatureDefs.new():WithFeatureDefs({
	[1] = { name = "treetype1" },
	[2] = { name = "rock1" },
})
_G.FeatureDefs = featureDefs:GetFeatureDefsByID()

local featureDestroyed = VFS.Include("luarules/mission_api/triggers/feature_destroyed.lua")
local onFeatureDestroyed = featureDestroyed.callins.FeatureDestroyed

describe("mission_api.triggers.feature_destroyed", function()
	local function trigger(parameters)
		return Builders.Trigger.new():WithParameters(parameters):Build()
	end

	local function newContext()
		local context = Builders.TriggerContext.new():Build()
		return context, context.timesFired
	end

	local triggerID = "t"

	local function destroyed(t, context, featureDefID, attackerAllyTeamID, reclaimerTeamID, reclaimLeft)
		onFeatureDestroyed(t, triggerID, context, 100, featureDefID, attackerAllyTeamID, reclaimerTeamID, reclaimLeft)
	end

	it("declares its type and parameters", function()
		assert.are.equal("FeatureDestroyed", featureDestroyed.type)
		local names = {}
		for _, parameter in ipairs(featureDestroyed.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.featureName)
		assert.is_true(names.featureDefName)
		assert.is_true(names.allyTeamID)
		assert.is_true(names.area)
		assert.are.same(
			{ "featureName", "featureDefName", "allyTeamID", "area" },
			featureDestroyed.parameters.requiresOneOf
		)
	end)

	it("does not fire when the feature was fully reclaimed", function()
		local context, fired = newContext()
		destroyed(trigger({ featureDefName = "treetype1" }), context, 1, nil, 2, 0)
		assert.are.equal(0, fired())
	end)

	it("filters by featureName", function()
		local context, fired = newContext()
		context.DoesFeatureHaveName = function()
			return false
		end
		destroyed(trigger({ featureName = "landmark" }), context, 1, 0, nil, nil)
		assert.are.equal(0, fired())
	end)

	it("filters by featureDefName", function()
		local context, fired = newContext()
		destroyed(trigger({ featureDefName = "rock1" }), context, 1, 0, nil, nil) -- featureDefID 1 = treetype1
		assert.are.equal(0, fired())
	end)

	it("filters by allyTeamID", function()
		local context, fired = newContext()
		destroyed(trigger({ featureDefName = "treetype1", allyTeamID = 1 }), context, 1, 0, nil, nil)
		assert.are.equal(0, fired())
	end)

	it("filters by area", function()
		local context, fired = newContext()
		context.IsFeatureInArea = function()
			return false
		end
		destroyed(trigger({ area = { x = 0, z = 0, radius = 10 } }), context, 1, 0, nil, nil)
		assert.are.equal(0, fired())
	end)

	it("fires when destroyed outright (no reclaimer)", function()
		local context, fired = newContext()
		destroyed(trigger({ featureDefName = "treetype1" }), context, 1, 0, nil, nil)
		assert.are.equal(1, fired())
	end)

	it("fires when partially reclaimed and then destroyed by other means", function()
		local context, fired = newContext()
		destroyed(trigger({ featureDefName = "treetype1" }), context, 1, 0, 2, 5)
		assert.are.equal(1, fired())
	end)
end)
