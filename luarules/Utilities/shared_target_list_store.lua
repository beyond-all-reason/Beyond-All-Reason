---Creates and deduplicates shared target-list value objects.
---
---The store owns list identity and the content-key lookup. It deliberately does
---not own unit assignment, reference counts, validation scheduling, or synced to
---unsynced transport; those are lifecycle concerns of the target gadget.
local SharedTargetListStore = {}

---@class SharedTargetList
---@field id integer
---@field key string?
---@field teamID TeamID
---@field allyTeam AllyTeamID
---@field entries UnitTargetEntry[]
---@field lookup table<number, integer>
---@field units table<integer, table> Assignment owners, including both command kinds.
---@field unavailable table<any, integer?> Tracking-state reason; nil means available.
---@field unseenUntil table<any, integer?> Slow-update frame at which an unseen target expires
---@field unseenUntilShared boolean? Expiry storage also belongs to a related reduced list
---@field validationIndex integer
---@field refCount integer

---@class SharedTargetListRemoval
---@field entries UnitTargetEntry[]
---@field key string
---@field lookup table<number, integer>?
---@field removals table<integer, SharedTargetListRemoval>?

---@class SharedTargetListStore
---@field sharedListsByKey table<string, SharedTargetList?>
---@field removalsByList table<SharedTargetList, table<integer, SharedTargetListRemoval>?>
---@field nextListID integer
local Store = {}
Store.__index = Store

local function targetKey(target)
	if type(target) == "number" then
		return "u" .. target
	end
	return "p" .. target[1] .. "," .. target[2] .. "," .. target[3]
end

local function targetEntryKey(targetData)
	return table.concat({
		targetKey(targetData.target),
		targetData.alwaysSeen and "1" or "0",
		targetData.ignoreStop and "1" or "0",
		targetData.userTarget and "1" or "0",
	}, ":")
end

local function sharedListKey(entries, teamID, allyTeam)
	local keyParts = { teamID, ":", allyTeam, "|" }
	for index = 1, #entries do
		keyParts[#keyParts + 1] = targetEntryKey(entries[index])
		keyParts[#keyParts + 1] = ";"
	end
	return table.concat(keyParts)
end

---Creates a new list value without adding it to the shared-content lookup.
---@param entries UnitTargetEntry[]
---@param teamID TeamID
---@param allyTeam AllyTeamID
---@param key string?
---@param lookup table<number, integer>? Existing immutable lookup for the same entries.
---@return SharedTargetList list
function Store:createTargetList(entries, teamID, allyTeam, key, lookup)
	if not lookup then
		lookup = {}
		for index = 1, #entries do
			local target = entries[index].target
			if type(target) == "number" then
				lookup[target] = index
			end
		end
	end

	local list = {
		id = self.nextListID,
		key = key,
		teamID = teamID,
		allyTeam = allyTeam,
		entries = entries,
		lookup = lookup,
		units = {},
		unavailable = {},
		unseenUntil = {},
		validationIndex = 1,
		refCount = 0,
	}
	self.nextListID = self.nextListID + 1
	return list
end

---Returns the existing list with the same complete value, or creates one.
---Team and ally-team identity are part of the value because visibility and
---alliance validation are shared by every unit referencing the list.
---@param entries UnitTargetEntry[]
---@param teamID TeamID
---@param allyTeam AllyTeamID
---@return SharedTargetList list
function Store:getOrCreateSharedTargetList(entries, teamID, allyTeam)
	local key = sharedListKey(entries, teamID, allyTeam)
	local list = self.sharedListsByKey[key]
	if list then
		return list
	end

	list = self:createTargetList(entries, teamID, allyTeam, key)
	self.sharedListsByKey[key] = list
	return list
end

---Shares the result of removing an entry, without copying and hashing it per owner.
---Only the value is cached: released lists get fresh validation/transport state.
---Retained targets keep the source expiry deadlines; removals do not renew them.
---@param source SharedTargetList
---@param index integer
---@return SharedTargetList? list Nil when the last entry is removed.
function Store:getSharedTargetListWithout(source, index)
	if #source.entries == 1 then
		return nil
	end
	local removals = self.removalsByList[source]
	local value = removals and removals[index]
	if not value then
		local entries = {}
		for oldIndex = 1, #source.entries do
			if oldIndex ~= index then
				entries[#entries + 1] = source.entries[oldIndex]
			end
		end
		value = { entries = entries, key = sharedListKey(entries, source.teamID, source.allyTeam) }
		removals = removals or {}
		self.removalsByList[source] = removals
		removals[index] = value
	end
	local list = self.sharedListsByKey[value.key]
	if not list then
		list = self:createTargetList(value.entries, source.teamID, source.allyTeam, value.key, value.lookup)
		self.sharedListsByKey[value.key] = list
		-- Deadlines are idempotent when related lists validate in the same frame.
		-- Share them in O(1), including recreated intermediate removal results.
		list.unseenUntil = source.unseenUntil
		list.unseenUntilShared = true
		source.unseenUntilShared = true
	end
	value.lookup = list.lookup
	-- Keep subsequent removals with the value too. Intermediate lists can lose
	-- their last owner while one unit skips several invalid targets in a row;
	-- the next owner must reuse that whole sequence, not copy it again.
	local nextRemovals = self.removalsByList[list] or value.removals or {}
	self.removalsByList[list] = nextRemovals
	value.removals = nextRemovals
	return list
end

---Removes a list from content-based sharing if it is still the indexed value.
---The list object remains valid for existing references.
---@param list SharedTargetList
function Store:removeSharedTargetList(list)
	self.removalsByList[list] = nil
	if list.key and self.sharedListsByKey[list.key] == list then
		self.sharedListsByKey[list.key] = nil
	end
end

---Detaches an exclusively owned list before an in-place mutation.
---@param list SharedTargetList
function Store:makeTargetListPrivate(list)
	if list.unseenUntilShared then
		-- A later append may reintroduce a removed target with a fresh lifetime.
		-- Detach once for that private edit, copying only currently retained targets.
		local deadlines = {}
		for _, entry in ipairs(list.entries) do
			deadlines[entry.target] = list.unseenUntil[entry.target]
		end
		list.unseenUntil = deadlines
		list.unseenUntilShared = nil
	end
	-- Cached values can share this list's entries, as a source or a result.
	-- Invalidate them before the caller appends to the entries in place.
	self.removalsByList = {}
	self:removeSharedTargetList(list)
	list.key = nil
end

---@return SharedTargetListStore
function SharedTargetListStore.new()
	return setmetatable({
		sharedListsByKey = {},
		removalsByList = {},
		nextListID = 1,
	}, Store)
end

return SharedTargetListStore
