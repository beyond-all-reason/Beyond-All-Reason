require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and FeatureDefs inside its handler.
Builders.MissionApi.new():Install()

local featureDefs = Builders.FeatureDefs.new():WithFeatureDefs({
	[1] = { name = "treetype1" },
	[2] = { name = "rock1" },
})
_G.FeatureDefs = featureDefs:GetFeatureDefsByID()

local featureCreated = VFS.Include("luarules/mission_api/triggers/feature_created.lua")
local onFeatureCreated = featureCreated.callins.FeatureCreated

describe("mission_api.triggers.feature_created", function()
	local function trigger(parameters)
		return Builders.Trigger.new():WithParameters(parameters):Build()
	end

	local function newContext()
		local context = Builders.TriggerContext.new():Build()
		return context, context.timesFired
	end

	local triggerID = "t"

	it("declares its type and parameters", function()
		assert.are.equal("FeatureCreated", featureCreated.type)
		local names = {}
		for _, parameter in ipairs(featureCreated.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.featureDefName)
		assert.is_true(names.area)
		assert.are.same({ "featureDefName", "area" }, featureCreated.parameters.requiresOneOf)
	end)

	it("filters by featureDefName", function()
		local context, fired = newContext()
		-- featureDefID 1 = treetype1
		onFeatureCreated(trigger({ featureDefName = "rock1" }), triggerID, context, 100, 1)
		assert.are.equal(0, fired())
	end)

	it("filters by area", function()
		local context, fired = newContext()
		context.IsFeatureInArea = function()
			return false
		end
		onFeatureCreated(trigger({ area = { x = 0, z = 0, radius = 10 } }), triggerID, context, 100, 1)
		assert.are.equal(0, fired())
	end)

	it("fires for a matching feature", function()
		local context, fired = newContext()
		onFeatureCreated(trigger({ featureDefName = "treetype1" }), triggerID, context, 100, 1)
		assert.are.equal(1, fired())
	end)
end)
