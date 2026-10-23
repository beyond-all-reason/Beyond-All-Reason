local Builders = VFS.Include("spec/builders/index.lua")
local ResourceTypes = require("gamedata/resource_types")

describe("ManualShareLedger", function()
	local ManualShareLedger = require("modules/transfer/economy/manual_share_ledger")
	local state = require("modules/transfer/state")

	before_each(function()
		-- the ledger is module state, shared by every instance: empty it between cases
		for teamId in pairs(state.manualShareLedger) do
			state.manualShareLedger[teamId] = nil
		end
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
		local first, second = assert(results[1]), assert(results[2])

		assert.is_near(160, first.sent, 1e-6)
		assert.is_near(0, first.received, 1e-6)
		assert.is_near(5 + 105, second.received, 1e-6)
	end)

	it("clears folded amounts so the next tick gets none", function()
		ManualShareLedger.Record(0, 1, ResourceTypes.METAL, 100, 70)
		ManualShareLedger.FoldInto(makeResults())

		local results = ManualShareLedger.FoldInto(makeResults())
		local first, second = assert(results[1]), assert(results[2])
		assert.is_near(10, first.sent, 1e-6)
		assert.is_near(5, second.received, 1e-6)
	end)

	it("does not touch deltas", function()
		ManualShareLedger.Record(0, 1, ResourceTypes.METAL, 100, 70)
		local results = ManualShareLedger.FoldInto(makeResults())
		local first, second = assert(results[1]), assert(results[2])
		assert.equal(0, first.delta)
		assert.equal(0, second.delta)
	end)
end)
