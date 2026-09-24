local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

local pipelines = ModuleHandler.LoadPolicies(Modules.Construction) ---@type ConstructionPipelines

local function decide(pipeline, ctx)
	return ModuleHandler.Evaluate(pipeline, ctx)
end

describe("construction policies", function()
	describe("assist", function()
		it("lets anyone help their own, and allies help when the mode is on", function()
			assert.is_true(
				decide(
					pipelines.assist,
					{ allied = false, targetComplete = false, targetIsBuilder = true, assistEnabled = false }
				)
			)
			assert.is_true(
				decide(
					pipelines.assist,
					{ allied = true, targetComplete = false, targetIsBuilder = true, assistEnabled = true }
				)
			)
		end)

		it("with the mode off, an ally may not help an unfinished unit or any builder", function()
			assert.is_false(
				decide(
					pipelines.assist,
					{ allied = true, targetComplete = false, targetIsBuilder = false, assistEnabled = false }
				)
			)
			assert.is_false(
				decide(
					pipelines.assist,
					{ allied = true, targetComplete = true, targetIsBuilder = true, assistEnabled = false }
				)
			)
			assert.is_true(
				decide(
					pipelines.assist,
					{ allied = true, targetComplete = true, targetIsBuilder = false, assistEnabled = false }
				)
			)
		end)
	end)

	describe("reclaim", function()
		it("with the mode off, allies may neither reclaim each other nor guard a reclaimer", function()
			assert.is_false(
				decide(
					pipelines.reclaim,
					{ allied = true, command = "reclaim", targetCanReclaim = false, reclaimEnabled = false }
				)
			)
			assert.is_false(
				decide(
					pipelines.reclaim,
					{ allied = true, command = "guard", targetCanReclaim = true, reclaimEnabled = false }
				)
			)
			assert.is_true(
				decide(
					pipelines.reclaim,
					{ allied = true, command = "guard", targetCanReclaim = false, reclaimEnabled = false }
				)
			)
			assert.is_true(
				decide(
					pipelines.reclaim,
					{ allied = true, command = "reclaim", targetCanReclaim = false, reclaimEnabled = true }
				)
			)
		end)
	end)

	describe("resurrect", function()
		it("a partly reclaimed wreck resurrects only when the mode allows", function()
			assert.is_true(decide(pipelines.resurrect, { partialAllowed = true }))
			assert.is_false(decide(pipelines.resurrect, { partialAllowed = false }))
		end)
	end)

	describe("build", function()
		it("a delayed builder builds nothing", function()
			assert.is_false(decide(pipelines.build, { builderID = 1, builderTeam = 0, delayed = true, part = 0.1 }))
			assert.is_true(decide(pipelines.build, { builderID = 1, builderTeam = 0, delayed = false, part = 0.1 }))
		end)
	end)

	describe("creation", function()
		it("construction itself refuses nobody; a tier gate is another module's guard", function()
			assert.is_true(
				decide(pipelines.creation, { unitDefID = 1, teamID = 0, tier = nil, unitDef = { isFactory = true } })
			)
		end)

		it("has no tier unless a module provides one", function()
			local Contract = VFS.Include("modules/construction/contract.lua")
			local resolved = ModuleHandler.LoadEnrichers(Contract.CreationFacts)
			local facts = ModuleHandler.EnrichWith(resolved, {}, { teamID = 0 })
			assert.is_nil(facts[Contract.CreationFacts.Tier])
		end)
	end)

	describe("placement", function()
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
				decide(
					pipelines.placement,
					at({ extractor = "mex", alliedExtractorNearby = true, utilitySharing = false })
				)
			)
			assert.is_true(
				decide(
					pipelines.placement,
					at({ extractor = "mex", alliedExtractorNearby = true, utilitySharing = true })
				)
			)
			assert.is_true(
				decide(
					pipelines.placement,
					at({ extractor = "geo", alliedExtractorNearby = false, utilitySharing = false })
				)
			)
			assert.is_true(
				decide(
					pipelines.placement,
					at({ extractor = nil, alliedExtractorNearby = true, utilitySharing = false })
				)
			)
		end)

		it("refuses an extractor on a spot an ally holds, and nothing an enemy holds", function()
			assert.is_false(
				decide(pipelines.placement, at({ extractor = "mex", spotHolder = 1, spotHolderAllied = true }))
			)
			assert.is_true(
				decide(pipelines.placement, at({ extractor = "mex", spotHolder = 1, spotHolderAllied = false }))
			)
			assert.is_true(
				decide(pipelines.placement, at({ extractor = "mex", spotHolder = 0, spotHolderAllied = false }))
			)
			assert.is_false(
				decide(pipelines.placement, at({ extractor = "geo", spotHolder = 1, spotHolderAllied = true })),
				"a geo spot too, once a module deals those"
			)
			assert.is_true(
				decide(pipelines.placement, at({ extractor = nil, spotHolder = 1, spotHolderAllied = true }))
			)
		end)

		it("lets a mex onto an ally's extractor on that ally's spot when utility buildings may change hands", function()
			local theirs = { extractor = "mex", spotHolder = 1, spotHolderAllied = true, alliedExtractorNearby = true }
			theirs.utilitySharing = true
			assert.is_true(decide(pipelines.placement, at(theirs)))
			theirs.utilitySharing = false
			assert.is_false(decide(pipelines.placement, at(theirs)))
		end)

		it("holds every spot for its builder, and shares no utilities, unless a module says otherwise", function()
			local Contract = VFS.Include("modules/construction/contract.lua")
			local resolved = ModuleHandler.LoadEnrichers(Contract.PlacementFacts)
			local facts = ModuleHandler.EnrichWith(resolved, {}, at({ extractor = "mex", builderTeam = 3 }))
			assert.are.equal(3, facts[Contract.PlacementFacts.SpotHolder])
			assert.is_false(facts[Contract.PlacementFacts.UtilitySharing])
		end)

	end)
end)
