local Builders = VFS.Include("spec/builders/index.lua")
local ResourceTypes = VFS.Include("gamedata/resource_types.lua")

describe("ManualShareLedger", function()
	local ManualShareLedger = VFS.Include("modules/transfer/economy/manual_share_ledger.lua")

	before_each(function()
		ManualShareLedger.Clear()
	end)

	local function makeResults()
		return {
			{ teamId = 0, resourceType = ResourceTypes.METAL, delta = 0, sent = 10, received = 0, excess = 0 },
			{ teamId = 1, resourceType = ResourceTypes.METAL, delta = 0, sent = 0, received = 5, excess = 0 },
		}
	end

	it("folds recorded transfers into result entries", function()
		ManualShareLedger.Record(0, 1, ResourceTypes.METAL, 100, 70)
		ManualShareLedger.Record(0, 1, ResourceTypes.METAL, 50, 35)

		local results = ManualShareLedger.FoldInto(makeResults())

		assert.is_near(160, results[1].sent, 1e-6)
		assert.is_near(0, results[1].received, 1e-6)
		assert.is_near(5 + 105, results[2].received, 1e-6)
	end)

	it("clears folded amounts so the next tick gets none", function()
		ManualShareLedger.Record(0, 1, ResourceTypes.METAL, 100, 70)
		ManualShareLedger.FoldInto(makeResults())

		local results = ManualShareLedger.FoldInto(makeResults())
		assert.is_near(10, results[1].sent, 1e-6)
		assert.is_near(5, results[2].received, 1e-6)
	end)

	it("does not touch deltas", function()
		ManualShareLedger.Record(0, 1, ResourceTypes.METAL, 100, 70)
		local results = ManualShareLedger.FoldInto(makeResults())
		assert.equal(0, results[1].delta)
		assert.equal(0, results[2].delta)
	end)
end)
