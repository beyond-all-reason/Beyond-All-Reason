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

	it("shares one removal across owners while retaining the original order and flags", function()
		local store = SharedTargetListStore.new()
		local entries = { entry(10), entry(20), entry({ 1, 2, 3 }, { userTarget = true }) }
		local source = store:getOrCreateSharedTargetList(entries, 1, 2)
		local reduced = store:getSharedTargetListWithout(source, 2)
		for _ = 1, 600 do
			assert.is_true(rawequal(reduced, store:getSharedTargetListWithout(source, 2)))
		end
		assert.same({ entries[1], entries[3] }, reduced.entries)
		assert.are.equal(3, #source.entries)
		assert.is_true(rawequal(reduced, store:getOrCreateSharedTargetList({ entries[1], entries[3] }, 1, 2)))
		assert.is_nil(store:getSharedTargetListWithout(store:getSharedTargetListWithout(reduced, 1), 1))
	end)

	it("reuses the removed value without reviving released list state", function()
		local store = SharedTargetListStore.new()
		local source = store:getOrCreateSharedTargetList({ entry(10), entry(20), entry(30) }, 1, 2)
		local reduced = store:getSharedTargetListWithout(source, 1)
		reduced.unavailable[20] = 2
		reduced.unseenUntil[20] = 60
		reduced.validationIndex = 2
		store:removeSharedTargetList(reduced)
		local recreated = store:getSharedTargetListWithout(source, 1)
		assert.are_not.equal(reduced.id, recreated.id)
		assert.is_true(rawequal(reduced.entries, recreated.entries))
		assert.same({}, recreated.unavailable)
		assert.are.equal(60, recreated.unseenUntil[20])
		assert.is_true(rawequal(source.unseenUntil, recreated.unseenUntil))
		assert.are.equal(1, recreated.validationIndex)
	end)

	it("inherits deadlines without copying them for each removal owner", function()
		local store = SharedTargetListStore.new()
		local source = store:getOrCreateSharedTargetList({ entry(10), entry(20), entry(30) }, 1, 2)
		source.unseenUntil[20] = 60
		for _ = 1, 600 do
			local reduced = store:getSharedTargetListWithout(source, 1)
			assert.is_true(rawequal(source.unseenUntil, reduced.unseenUntil))
			assert.are.equal(60, reduced.unseenUntil[20])
			store:removeSharedTargetList(reduced)
		end
	end)

	it("isolates deadlines before a private edit reintroduces a removed target", function()
		local store = SharedTargetListStore.new()
		local source = store:getOrCreateSharedTargetList({ entry(10), entry(20), entry(30) }, 1, 2)
		source.unseenUntil[10] = 45
		source.unseenUntil[20] = 60
		local reduced = store:getSharedTargetListWithout(source, 1)
		store:makeTargetListPrivate(reduced)
		assert.is_nil(reduced.unseenUntil[10])
		assert.are.equal(60, reduced.unseenUntil[20])
		reduced.unseenUntil[20] = nil
		assert.are.equal(60, source.unseenUntil[20])
	end)

	it("invalidates removals before a source list is extended in place", function()
		local store = SharedTargetListStore.new()
		local source = store:getOrCreateSharedTargetList({ entry(10), entry(20) }, 1, 2)
		store:getSharedTargetListWithout(source, 1)
		store:makeTargetListPrivate(source)
		source.entries[3] = entry(30)
		source.lookup[30] = 3
		assert.same({ entry(20), entry(30) }, store:getSharedTargetListWithout(source, 1).entries)
	end)

	it("reuses consecutive removals even when each intermediate list is released", function()
		local store = SharedTargetListStore.new()
		local source = store:getOrCreateSharedTargetList({ entry(10), entry(20), entry(30), entry(40) }, 1, 2)
		local intermediate = store:getSharedTargetListWithout(source, 1)
		local reduced = store:getSharedTargetListWithout(intermediate, 1)
		for _ = 1, 600 do
			store:removeSharedTargetList(intermediate)
			store:removeSharedTargetList(reduced)
			local nextIntermediate = store:getSharedTargetListWithout(source, 1)
			local nextReduced = store:getSharedTargetListWithout(nextIntermediate, 1)
			assert.is_true(rawequal(intermediate.entries, nextIntermediate.entries))
			assert.is_true(rawequal(intermediate.lookup, nextIntermediate.lookup))
			assert.is_true(rawequal(reduced.entries, nextReduced.entries))
			assert.is_true(rawequal(reduced.lookup, nextReduced.lookup))
			assert.same({ entry(30), entry(40) }, nextReduced.entries)
			intermediate, reduced = nextIntermediate, nextReduced
		end
	end)

	it("does not reuse entries changed by a private edit of a removal result", function()
		local store = SharedTargetListStore.new()
		local source = store:getOrCreateSharedTargetList({ entry(10), entry(20) }, 1, 2)
		local reduced = store:getSharedTargetListWithout(source, 1)
		store:makeTargetListPrivate(reduced)
		reduced.entries[2] = entry(30)
		reduced.lookup[30] = 2
		local shared = store:getSharedTargetListWithout(source, 1)
		assert.same({ entry(20) }, shared.entries)
		assert.same({ entry(20), entry(30) }, reduced.entries)
	end)
end)
