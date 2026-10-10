local Modules = require("modules/enums").Modules
local ModuleHandler = require("modules/module_handler")

local function decide(policy, ctx)
	return ModuleHandler.Evaluate(policy, ctx)
end

describe("a spot a builder wants to build on", function()
	local Contract = ModuleHandler.Contract(Modules.Construction)

	local spot = { unitDefID = 7, builderTeam = 0, x = 0, y = 0, z = 0, spotHolder = 0 }
	local function at(extra)
		local ctx = {}
		for k, v in pairs(spot) do
			ctx[k] = v
		end
		for k, v in pairs(extra) do
			ctx[k] = v
		end
		return ctx
	end

	it("an ally's extractor spot is taken unless utility buildings may change hands", function()
		assert.is_false(
			decide(Contract.Placement, at({ extractor = "mex", alliedExtractorNearby = true, utilitySharing = false }))
		)
		assert.is_true(
			decide(Contract.Placement, at({ extractor = "mex", alliedExtractorNearby = true, utilitySharing = true }))
		)
		assert.is_true(
			decide(Contract.Placement, at({ extractor = "geo", alliedExtractorNearby = false, utilitySharing = false }))
		)
		assert.is_true(
			decide(Contract.Placement, at({ extractor = nil, alliedExtractorNearby = true, utilitySharing = false }))
		)
	end)

	it("refuses an extractor on a spot an ally holds, and nothing an enemy holds", function()
		assert.is_false(decide(Contract.Placement, at({ extractor = "mex", spotHolder = 1, spotHolderAllied = true })))
		assert.is_true(decide(Contract.Placement, at({ extractor = "mex", spotHolder = 1, spotHolderAllied = false })))
		assert.is_true(decide(Contract.Placement, at({ extractor = "mex", spotHolder = 0, spotHolderAllied = false })))
		assert.is_false(
			decide(Contract.Placement, at({ extractor = "geo", spotHolder = 1, spotHolderAllied = true })),
			"a geo spot too, once a module deals those"
		)
		assert.is_true(decide(Contract.Placement, at({ extractor = nil, spotHolder = 1, spotHolderAllied = true })))
	end)

	it("lets a mex onto an ally's extractor on that ally's spot when utility buildings may change hands", function()
		local theirs = { extractor = "mex", spotHolder = 1, spotHolderAllied = true, alliedExtractorNearby = true }
		theirs.utilitySharing = true
		assert.is_true(decide(Contract.Placement, at(theirs)))
		theirs.utilitySharing = false
		assert.is_false(decide(Contract.Placement, at(theirs)))
	end)

	it("holds every spot for its builder, and shares no utilities, unless a module says otherwise", function()
		local resolved = ModuleHandler.LoadEnrichers(Contract.PlacementFacts)
		local facts = ModuleHandler.EnrichWith(resolved, {}, at({ extractor = "mex", builderTeam = 3 }))
		assert.are.equal(3, facts[Contract.PlacementFacts.SpotHolder])
		assert.is_nil(facts[Contract.PlacementFacts.UtilitySharing])
	end)
end)
