local SharedTargetListStore = VFS.Include("luarules/Utilities/shared_target_list_store.lua")

local function entry(target, overrides)
	local value = {
		target = target,
		alwaysSeen = false,
		ignoreStop = false,
		userTarget = false,
	}
	for key, override in pairs(overrides or {}) do
		value[key] = override
	end
	return value
end

describe("shared target-list store", function()
	it("reuses lists with the same complete value", function()
		local store = SharedTargetListStore.new()
		local first = store:getOrCreateSharedTargetList({ entry(10), entry({ 1, 2, 3 }) }, 4, 5)
		local second = store:getOrCreateSharedTargetList({ entry(10), entry({ 1, 2, 3 }) }, 4, 5)

		assert.is_true(rawequal(first, second))
		assert.are.equal(1, first.lookup[10])
		assert.is_nil(first.lookup[1])
	end)

	it("keeps order, flags, team, and ally team in the shared value", function()
		local store = SharedTargetListStore.new()
		local baseline = store:getOrCreateSharedTargetList({ entry(10), entry(20) }, 1, 2)

		assert.is_false(rawequal(baseline, store:getOrCreateSharedTargetList({ entry(20), entry(10) }, 1, 2)))
		assert.is_false(
			rawequal(baseline, store:getOrCreateSharedTargetList({ entry(10, { userTarget = true }), entry(20) }, 1, 2))
		)
		assert.is_false(rawequal(baseline, store:getOrCreateSharedTargetList({ entry(10), entry(20) }, 3, 2)))
		assert.is_false(rawequal(baseline, store:getOrCreateSharedTargetList({ entry(10), entry(20) }, 1, 4)))
	end)

	it("allows a detached list value to be recreated and shared", function()
		local store = SharedTargetListStore.new()
		local entries = { entry(10), entry(20) }
		local detached = store:getOrCreateSharedTargetList(entries, 1, 2)
		store:makeTargetListPrivate(detached)
		local shared = store:getOrCreateSharedTargetList(entries, 1, 2)

		assert.is_false(rawequal(detached, shared))
		assert.is_nil(detached.key)
		assert.are_not.equal(detached.id, shared.id)
		assert.is_true(rawequal(shared, store:getOrCreateSharedTargetList(entries, 1, 2)))
	end)

	it("does not let removal of an old value evict its replacement", function()
		local store = SharedTargetListStore.new()
		local entries = { entry(10) }
		local old = store:getOrCreateSharedTargetList(entries, 1, 2)
		store:removeSharedTargetList(old)
		local replacement = store:getOrCreateSharedTargetList(entries, 1, 2)
		store:removeSharedTargetList(old)

		assert.is_true(rawequal(replacement, store:getOrCreateSharedTargetList(entries, 1, 2)))
	end)
end)
