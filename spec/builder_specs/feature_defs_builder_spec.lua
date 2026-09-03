require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

describe("FeatureDefsBuilder", function()
	it("starts empty", function()
		local defs = Builders.FeatureDefs.new()

		assert.are.same({}, defs:GetFeatureDefsByID())
		assert.are.same({}, defs:GetFeatureDefsByName())
		assert.are.same({}, defs:GetFeatureDefNames())
	end)

	it("registers a def under both its ID and its name", function()
		local defs =
			Builders.FeatureDefs.new():WithFeatureDef(1, { name = "treetype1" }):WithFeatureDef(2, { name = "rock1" })

		assert.are.equal("treetype1", defs:GetFeatureDefsByID()[1].name)
		assert.are.equal("rock1", defs:GetFeatureDefsByID()[2].name)
		assert.are.equal(defs:GetFeatureDefsByID()[1], defs:GetFeatureDefsByName()["treetype1"])
		assert.are.same({ id = 2 }, defs:GetFeatureDefNames()["rock1"])
	end)

	it("keeps an unnamed def addressable by ID", function()
		local defs = Builders.FeatureDefs.new():WithFeatureDef(1, { reclaimable = true })

		assert.is_true(defs:GetFeatureDefsByID()[1].reclaimable)
		assert.are.same({}, defs:GetFeatureDefsByName())
	end)
end)
