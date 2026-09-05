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
---@field units table<integer, boolean>
---@field unavailable table<any, boolean?>
---@field unseenSince table<any, integer?>
---@field validationIndex integer
---@field refCount integer

---@class SharedTargetListStore
---@field sharedListsByKey table<string, SharedTargetList?>
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
---@return SharedTargetList list
function Store:createTargetList(entries, teamID, allyTeam, key)
	local lookup = {}
	for index = 1, #entries do
		local target = entries[index].target
		if type(target) == "number" then
			lookup[target] = index
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
		unseenSince = {},
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

---Removes a list from content-based sharing if it is still the indexed value.
---The list object remains valid for existing references.
---@param list SharedTargetList
function Store:removeSharedTargetList(list)
	if list.key and self.sharedListsByKey[list.key] == list then
		self.sharedListsByKey[list.key] = nil
	end
end

---Detaches an exclusively owned list before an in-place mutation.
---@param list SharedTargetList
function Store:makeTargetListPrivate(list)
	self:removeSharedTargetList(list)
	list.key = nil
end

---@return SharedTargetListStore
function SharedTargetListStore.new()
	return setmetatable({
		sharedListsByKey = {},
		nextListID = 1,
	}, Store)
end

return SharedTargetListStore
