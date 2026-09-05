--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    synthetic_callins.lua
--  brief:   registry of the callins that gadgets.lua dispatches for itself
--
--  These are artificially created within the game code to emulate the behaviors
--  of engine-driven callins. We are filling the gaps produced by the engine's
--  event system, in many cases, so code built on top of these foundations needs
--  to keep up with the times and adapt as the gaps fill in from the other side.
--
--  This also produces a few types of "summary views" over a base callin:
--  - *Post.* This is a mark-and-sweep pattern to update dirtied IDs.
--  - *Total.* This is an accumulator with a hook for custom results.
--  - *Transition.* Tracks state changes, holding a latch and ignoring loops.
--
--  Adding a new callin:
--  1. Add the callin's envs and subscriptions to syntheticCallins.
--  2. If producing a summary view, add to one of the following sets:
--     `syntheticCallinSummaries`:
--     This produces both the <Base>Post and <Base>Total callins and
--     adds the custom GG.Accumulate<Base> hook later during install.
--     `syntheticCallinTransitions`:
--     This produces only the <Base>Post callin and collects state changes
--     to be raised later only if they do not resolve subframe, eg A->B->A.
--  3. If the callin tracks more state, add it to syntheticCallinUpdate.
--  4. Add the callin's implementation (and locals) to the Dispatch section.
--  5. Add the callin to the handler in the Install section.
--  6. Document the callin for addons in types/SyntheticCallins.lua.

local env = Script.GetSynced() and "synced" or "unsynced"

--------------------------------------------------------------------------------
--  Declarations  --------------------------------------------------------------

-- Synthetic callins that subscribe to engine callins are kept installed for
-- as long as anything subscribes to them. These _must_ be recorded here or
-- can become unhooked whenever no addon happens to subscribe to their base.
local syntheticCallins = {
	shared = {
		MetaUnitAdded = { "UnitGiven", "UnitCreated" },
		MetaUnitRemoved = { "UnitTaken", "UnitDestroyed" },
	},

	synced = {
		UnitAutoTargetRange = { "AllowWeaponTarget" },
		UnitBuildStepPost = { "GameFramePost", "AllowUnitBuildStep" },
		FeatureBuildStepPost = { "GameFramePost", "AllowFeatureBuildStep" },
		UnitBuildStepTotal = { "GameFramePost", "AllowUnitBuildStep" },
		FeatureBuildStepTotal = { "GameFramePost", "AllowFeatureBuildStep" },
		UnitIdlePost = { "GameFramePost", "UnitIdle", "UnitCommand", "UnitTaken", "UnitDestroyed" }, -- See modules/unit_idle_states.lua.
	},

	unsynced = {},
}

local syntheticCallinSummaries = {
	UnitBuildStep = true,
	FeatureBuildStep = true,
}

local syntheticCallinTransitions = {
	UnitIdle = true,
}

-- The engine does not know these names, so `Script.UpdateCallIn` is a no-op.
-- We have to handle dropping tracked state, etc., during updates on our own.
-- Update handlers receive the gadgetHandler to read their subscriber lists.
local syntheticCallinUpdate = {}

--------------------------------------------------------------------------------
--  Callin setup  --------------------------------------------------------------

local syntheticCallinHold = table.merge(syntheticCallins.shared, syntheticCallins[env])
local callinNames = table.keys(syntheticCallinHold)

local callinHoldSummary = {}
for name, callinHolds in pairs(syntheticCallinHold) do
	for _, callin in ipairs(callinHolds) do
		local listName = callin .. "List"
		local holders = callinHoldSummary[listName]
		if not holders then
			holders = {}
			callinHoldSummary[listName] = holders
		end
		holders[#holders + 1] = name .. "List"
	end
end

---Engine callins stay installed while a synthetic reading them has subscribers.
local function holdsCallIn(self, listName)
	local holders = callinHoldSummary[listName]
	if not holders then
		return false
	end
	for _, holder in ipairs(holders) do
		if #self[holder] > 0 then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------
--  Callin summary views  ------------------------------------------------------

local marks = {}
local accumulate = {}

local function makeStopMarking(marked, list, count)
	return function()
		for i = 1, count[1] or 0 do
			marked[list[i]] = nil
		end
		count[1] = nil
	end
end

---Marked IDs this frame, as a set.
---@alias SummaryMarked table<ObjectID, true>

---Marked IDs this frame, as an array.
---@alias SummaryList ObjectID[]

---Signed sums per marked ID, kept while active.
---@alias SummaryTotals table<ObjectID, number>

---@class SummaryCount
---@field [1] integer? the batch size; nil is inactive

---@class SummaryActive
---@field [1] true? whether accumulating totals

---Sticky-state per marked ID, kept while active.
---@alias SummaryLatched table<ObjectID, true>

local function createSummary(callinName)
	if not syntheticCallinSummaries[callinName] then
		return
	end

	---@type SummaryMarked, SummaryList, SummaryCount
	local marked, list, count = {}, {}, table.new(1, 0)
	---@type SummaryTotals, SummaryActive
	local totals, active = {}, table.new(1, 0)
	local stop = makeStopMarking(marked, list, count)

	marks[callinName] = { marked = marked, list = list, count = count, totals = totals, active = active, stop = stop }

	accumulate["Accumulate" .. callinName] = function(id, amount)
		-- Call sites must not accumulate when not subscribed.
		local n = count[1]
		if not n then
			return
		end
		if not marked[id] then
			marked[id] = true
			n = n + 1
			count[1] = n
			list[n] = id
			if active[1] then
				totals[id] = amount
			end
		elseif active[1] then
			totals[id] = (totals[id] or 0) + amount
		end
	end

	-- Both summary views share updates so must handle updating together.
	local postList = callinName .. "PostList"
	local totalList = callinName .. "TotalList"
	local function update(gh)
		if #gh[totalList] > 0 then
			active[1] = true
		elseif active[1] then
			for i = 1, count[1] or 0 do
				-- ObjectID is a union of two integer aliases, which the checker will not
				-- accept as the key of a table it is clearing an entry from.
				---@diagnostic disable-next-line: inject-field
				totals[list[i]] = nil
			end
			active[1] = nil
		end
		if #gh[postList] > 0 or active[1] then
			count[1] = count[1] or 0
		else
			stop()
		end
	end
	syntheticCallinUpdate[callinName .. "Post"] = update
	syntheticCallinUpdate[callinName .. "Total"] = update
end

local function createTransition(callinName)
	if not syntheticCallinTransitions[callinName] then
		return
	end

	---@type SummaryMarked, SummaryList, SummaryCount
	local marked, list, count = {}, {}, table.new(1, 0)
	---@type SummaryLatched
	local latched = {}
	local stop = makeStopMarking(marked, list, count)

	marks[callinName] = { marked = marked, list = list, count = count, latched = latched, stop = stop }

	local postList = callinName .. "PostList"
	syntheticCallinUpdate[callinName .. "Post"] = function(gh)
		if #gh[postList] > 0 then
			count[1] = count[1] or 0
		else
			stop()
			-- After the last subscriber drops, any late-subscribers cannot trust
			-- the latched states anymore, so the states also must be dropped.
			for id in pairs(latched) do
				latched[id] = nil
			end
		end
	end
end

---A summary's marking state. Callins from non-matching envs get empty tables.
---@param baseName string
---@return SummaryMarked marked
---@return SummaryList   list
---@return SummaryCount  count
---@return SummaryTotals totals
---@return SummaryActive active
local function getMarks(baseName)
	local mark = marks[baseName]
	if not mark then
		if not syntheticCallinSummaries[baseName] and not syntheticCallinTransitions[baseName] then
			error("synthetic_callins: no such summary: " .. tostring(baseName))
		end
		return {}, {}, {}, {}, {}
	end
	return mark.marked, mark.list, mark.count, mark.totals, mark.active
end

local function getMarksUnsafe(baseName)
	local mark = marks[baseName]
	return mark.marked, mark.list, mark.count, mark.totals, mark.active
end

---@return SummaryLatched latched
local function getLatchUnsafe(baseName)
	return marks[baseName].latched
end

local function createSweep(callinName)
	local marked, list, countBox, totals, activeBox = getMarksUnsafe(callinName)
	local values = {}
	local postName, totalName = callinName .. "Post", callinName .. "Total"
	local postListName, totalListName = postName .. "List", totalName .. "List"

	return function(handler)
		local count = countBox[1]
		if not count or count == 0 then
			return
		end
		countBox[1] = 0

		-- This safely allows starting or ending subscriptions in Post.
		local active = activeBox[1]

		-- Clear marks first so subscribers that throw do not leave any marks.
		if active then
			for i = 1, count do
				local id = list[i]
				values[i] = totals[id] or 0
				totals[id] = nil
				marked[id] = nil
			end
		else
			for i = 1, count do
				marked[list[i]] = nil
			end
		end

		local postList = handler[postListName]
		for i = 1, count do
			local id = list[i]
			for _, g in ipairs(postList) do
				g[postName](g, id)
			end
		end

		if active then
			local totalList = handler[totalListName]
			for i = 1, count do
				local id, part = list[i], values[i]
				for _, g in ipairs(totalList) do
					g[totalName](g, id, part)
				end
			end
		end
	end
end

---We distrust the engine's `:UnitIdle` callin so read the unit queue directly.
---See unit_idle_states.lua for detail on unit behaviors, namely, "idle tasks".
local function createUnitIdleSweep()
	local marked, list, countBox = getMarksUnsafe("UnitIdle")
	local latched = getLatchUnsafe("UnitIdle")
	local transitions, states = {}, {}

	local VFSMODE = Spring.IsDevLuaEnabled() and VFS.RAW_FIRST or VFS.ZIP_ONLY
	local isIdle = VFS.Include("modules/unit_idle_states.lua", nil, VFSMODE).IsIdle

	local spGetUnitDefID = Spring.GetUnitDefID
	local spGetUnitIsDead = Spring.GetUnitIsDead

	return function(handler)
		local count = countBox[1]
		if not count or count == 0 then
			return
		end
		countBox[1] = 0

		-- Clear marks first so subscribers that throw do not leave any marks.
		-- Gathering the batch up front also lets subscribers re-mark safely.
		local n = 0
		for i = 1, count do
			local unitID = list[i]
			marked[unitID] = nil

			-- Units can be finalized between mark and sweep. Ignore dying units.
			local unitDefID = spGetUnitDefID(unitID)
			if unitDefID and spGetUnitIsDead(unitID) == false then
				local idle = isIdle(unitID, unitDefID)
				if idle ~= (latched[unitID] == true) then
					latched[unitID] = idle or nil
					n = n + 1
					transitions[n] = unitID
					states[n] = idle
				end
			else
				latched[unitID] = nil
			end
		end

		local postList = handler.UnitIdlePostList
		for i = 1, n do
			local unitID, idled = transitions[i], states[i]
			for _, g in ipairs(postList) do
				g:UnitIdlePost(unitID, idled)
			end
		end
	end
end

--------------------------------------------------------------------------------
--  Dispatch  ------------------------------------------------------------------
--
--  Callin implementations attach to the gadgetHandler in the Install section.
--
--  - UnitAutoTargetRange has its base implementation in gadgets.lua, instead.

local callins = {}

-- Shared environment

function callins.MetaUnitAdded(self, unitID, unitDefID, unitTeam)
	for _, g in ipairs(self.MetaUnitAddedList) do
		g:MetaUnitAdded(unitID, unitDefID, unitTeam)
	end
end

function callins.MetaUnitRemoved(self, unitID, unitDefID, unitTeam)
	for _, g in ipairs(self.MetaUnitRemovedList) do
		g:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	end
end

-- Synced environment

if Script.GetSynced() then
	createSummary("UnitBuildStep")
	callins.SweepUnitBuildStep = createSweep("UnitBuildStep")

	createSummary("FeatureBuildStep")
	callins.SweepFeatureBuildStep = createSweep("FeatureBuildStep")

	createTransition("UnitIdle")
	callins.SweepUnitIdle = createUnitIdleSweep()
end

-- Unsynced environment

if not Script.GetSynced() then

end

--------------------------------------------------------------------------------
--  Install  -------------------------------------------------------------------

local function install(handler)
	handler.HoldsCallIn = holdsCallIn

	---Synthetic callins have no engine hook, so they update their holds instead.
	local updateCallIn = handler.UpdateCallIn
	function handler:UpdateCallIn(name)
		local callinHolds = syntheticCallinHold[name]
		if not callinHolds then
			return updateCallIn(self, name)
		end

		local updateCallin = syntheticCallinUpdate[name]
		if updateCallin then
			updateCallin(self)
		end
		for _, callin in ipairs(callinHolds) do
			self:UpdateCallIn(callin)
		end
	end

	handler.MetaUnitAdded = callins.MetaUnitAdded
	handler.MetaUnitRemoved = callins.MetaUnitRemoved

	-- Wrap multi-env dispatchers for single-env synthetic callins at install
	-- to prevent errors caused by discrepancies between here and gadgets.lua

	if Script.GetSynced() then
		local gameFramePost = handler.GameFramePost
		local sweepUnitBuildStep = callins.SweepUnitBuildStep
		local sweepFeatureBuildStep = callins.SweepFeatureBuildStep
		local sweepUnitIdle = callins.SweepUnitIdle

		function handler:GameFramePost(frameNum)
			tracy.ZoneBeginN("G:GameFramePostSummary")
			sweepUnitBuildStep(self)
			sweepFeatureBuildStep(self)
			sweepUnitIdle(self)
			tracy.ZoneEnd()

			return gameFramePost(self, frameNum)
		end

		for name, hook in pairs(accumulate) do
			handler.GG[name] = hook
		end
	end

	if not Script.GetSynced() then

	end
end

--------------------------------------------------------------------------------
--  Exports  -------------------------------------------------------------------

---Synthetic callin registry and dispatch for gadgets.lua.
---@class SyntheticCallinsAPI
local synthetic = {
	install = install,
	getMarks = getMarks,
	callinNames = callinNames,
}

return synthetic
