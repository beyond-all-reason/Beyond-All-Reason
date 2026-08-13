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
--  Adding a new callin:
--  1. Add the callin's envs and subscriptions to syntheticCallins.
--  2. If using mark-and-sweep, add the callin to syntheticCallinMarks;
--     if adding up a running total, instead: to syntheticCallinTotals.
--  3. If the callin tracks more state, add it to syntheticCallinUpdate.
--  4. Add the callin's implementation (and locals) to the Dispatch section.

--------------------------------------------------------------------------------
--  Declarations  --------------------------------------------------------------

-- Synthetic callins that subscribe to engine callins are kept installed for
-- as long as anything subscribes to them. These _must_ be recorded here or
-- can become unhooked whenever no addon happens to subscribe to their base.
local syntheticCallins = {
	shared = {
		MetaUnitAdded   = { 'UnitGiven', 'UnitCreated' },
		MetaUnitRemoved = { 'UnitTaken', 'UnitDestroyed' },
	},

	synced = {
		UnitAutoTargetRange   = { 'AllowWeaponTarget' },
		UnitBuildStepPost     = { 'GameFramePost', 'AllowUnitBuildStep' },
		FeatureBuildStepPost  = { 'GameFramePost', 'AllowFeatureBuildStep' },
		UnitBuildStepTotal    = { 'GameFramePost', 'AllowUnitBuildStep' },
		FeatureBuildStepTotal = { 'GameFramePost', 'AllowFeatureBuildStep' },
	},

	unsynced = {},
}

local syntheticCallinHold = {}
for name, callinHolds in pairs(syntheticCallins.shared) do
	syntheticCallinHold[name] = callinHolds
end
for name, callinHolds in pairs(Script.GetSynced() and syntheticCallins.synced or syntheticCallins.unsynced) do
	syntheticCallinHold[name] = callinHolds
end

local callinHoldSummary = {}
for name, callinHolds in pairs(syntheticCallinHold) do
	for _, callin in ipairs(callinHolds) do
		local listName = callin .. 'List'
		local holders = callinHoldSummary[listName]
		if not holders then
			holders = {}
			callinHoldSummary[listName] = holders
		end
		holders[#holders + 1] = name .. 'List'
	end
end

---Engine callins stay installed while a synthetic reading them has subscribers.
function gadgetHandler:HoldsCallIn(listName)
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

-- The engine does not know these names, so `Script.UpdateCallIn` is a no-op.
-- We have to handle dropping tracked state, etc., during updates on our own.
local syntheticCallinUpdate = {}

--------------------------------------------------------------------------------
--  Callin mark-and-sweep  -----------------------------------------------------
--  
--  Entries below gain the `prefixMarked`, `prefixList` and `prefixCount` tables,
--  plus a function to stop marking, which their update handler calls on removal.

local syntheticCallinMarks = {
	UnitBuildStepPost    = 'unitStep',
	FeatureBuildStepPost = 'featureStep',
}

local syntheticCallinTotals = {
	UnitBuildStepTotal    = 'unitStepTotal',
	FeatureBuildStepTotal = 'featureStepTotal',
}

-- [markPrefix] := { marked, list, count, stop }
local marks = {}

local function makeStopMarking(marked, list, count)
	return function()
		for i = 1, count[1] or 0 do
			marked[list[i]] = nil
		end
		count[1] = nil
	end
end

local function createSweep(callinName, prefix)
	if not prefix then
		return
	end

	local marked, list, count = {}, {}, { nil } -- luahax: a constant-size array
	local stop = makeStopMarking(marked, list, count)

	marks[prefix] = { marked = marked, list = list, count = count, stop = stop }

	syntheticCallinUpdate[callinName] = function(active)
		if active then
			count[1] = count[1] or 0
		else
			stop()
		end
	end
end

local function createMarks(callinName)
	return createSweep(callinName, syntheticCallinMarks[callinName])
end

local function createTotals(callinName)
	return createSweep(callinName, syntheticCallinTotals[callinName])
end

-- prefix -> marked, list, count
local function getMarks(prefix)
	local mark = marks[prefix]
	if not mark then
		return
	end
	return mark.marked, mark.list, mark.count
end

local function getMarksUnsafe(prefix)
	local mark = marks[prefix]
	return mark.marked, mark.list, mark.count
end

--------------------------------------------------------------------------------
--  Dispatch  ------------------------------------------------------------------
--
--  The gadgetHandler is available at load time, so we implement callins here.
--  
--  - UnitAutoTargetRange has its base implementation in gadgets.lua, instead.

-- Shared environment

function gadgetHandler:MetaUnitAdded(unitID, unitDefID, unitTeam)
	for _, g in ipairs(self.MetaUnitAddedList) do
		g:MetaUnitAdded(unitID, unitDefID, unitTeam)
	end
end

function gadgetHandler:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	for _, g in ipairs(self.MetaUnitRemovedList) do
		g:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	end
end

-- Synced environment

if Script.GetSynced() then
	createMarks('UnitBuildStepPost')
	local unitStepMarked, unitStepList, unitStepCount = getMarksUnsafe('unitStep')

	function gadgetHandler:UnitBuildStepPost()
		local count = unitStepCount[1]
		if not count or count == 0 then
			return
		end
		unitStepCount[1] = 0

		-- Clear marks first so a subscriber that throws does not leave any marks.
		for i = 1, count do
			unitStepMarked[unitStepList[i]] = nil
		end

		-- Each subscriber receives the full batch at once, in layer order.
		-- This is an optimization that scales into much higher event counts.
		for _, g in ipairs(self.UnitBuildStepPostList) do
			local callin = g.UnitBuildStepPost
			for i = 1, count do
				callin(g, unitStepList[i])
			end
		end
	end

	createMarks('FeatureBuildStepPost')
	local featureStepMarked, featureStepList, featureStepCount = getMarksUnsafe('featureStep')

	function gadgetHandler:FeatureBuildStepPost()
		local count = featureStepCount[1]
		if not count or count == 0 then
			return
		end
		featureStepCount[1] = 0

		-- Clear marks first so a subscriber that throws does not leave any marks.
		for i = 1, count do
			featureStepMarked[featureStepList[i]] = nil
		end

		for _, g in ipairs(self.FeatureBuildStepPostList) do
			local callin = g.FeatureBuildStepPost
			for i = 1, count do
				callin(g, featureStepList[i])
			end
		end
	end

	createTotals('UnitBuildStepTotal')
	local unitStepTotalMarked, unitStepTotalList, unitStepTotalCount = getMarksUnsafe('unitStepTotal')
	local unitStepTotals = {}

	function gadgetHandler:UnitBuildStepTotal()
		local count = unitStepTotalCount[1]
		if not count or count == 0 then
			return
		end
		unitStepTotalCount[1] = 0

		-- Clear marks first so a subscriber that throws does not leave any marks.
		for i = 1, count do
			local unitID = unitStepTotalList[i]
			unitStepTotals[i] = unitStepTotalMarked[unitID]
			unitStepTotalMarked[unitID] = nil
		end

		for _, g in ipairs(self.UnitBuildStepTotalList) do
			local callin = g.UnitBuildStepTotal
			for i = 1, count do
				callin(g, unitStepTotalList[i], unitStepTotals[i])
			end
		end
	end

	createTotals('FeatureBuildStepTotal')
	local featureStepTotalMarked, featureStepTotalList, featureStepTotalCount = getMarksUnsafe('featureStepTotal')
	local featureStepTotals = {}

	function gadgetHandler:FeatureBuildStepTotal()
		local count = featureStepTotalCount[1]
		if not count or count == 0 then
			return
		end
		featureStepTotalCount[1] = 0

		-- Clear marks first so a subscriber that throws does not leave any marks.
		for i = 1, count do
			local featureID = featureStepTotalList[i]
			featureStepTotals[i] = featureStepTotalMarked[featureID]
			featureStepTotalMarked[featureID] = nil
		end

		for _, g in ipairs(self.FeatureBuildStepTotalList) do
			local callin = g.FeatureBuildStepTotal
			for i = 1, count do
				callin(g, featureStepTotalList[i], featureStepTotals[i])
			end
		end
	end
end

-- Unsynced environment

if not Script.GetSynced() then

end

--------------------------------------------------------------------------------
--  Install  -------------------------------------------------------------------

local function install(gh)
	local updateCallIn = gh.UpdateCallIn

	---Synthetic callins have no engine hook, so they update their holds instead.
	function gh:UpdateCallIn(name)
		local callinHolds = syntheticCallinHold[name]
		if not callinHolds then
			return updateCallIn(self, name)
		end

		local handleUpdate = syntheticCallinUpdate[name]
		if handleUpdate then
			handleUpdate(#self[name .. 'List'] > 0)
		end
		for _, callin in ipairs(callinHolds) do
			self:UpdateCallIn(callin)
		end
	end

	-- Wrap multi-env dispatchers for single-env synthetic callins at install
	-- to prevent errors caused by discrepancies between here and gadgets.lua

	-- This is the part of lua that no cleverness can help with: composition.

	if Script.GetSynced() then
		local gameFramePost = gh.GameFramePost
		function gh:GameFramePost(frameNum)
			tracy.ZoneBeginN("G:GameFrameSummary")
			self:UnitBuildStepPost()
			self:FeatureBuildStepPost()
			self:UnitBuildStepTotal()
			self:FeatureBuildStepTotal()
			tracy.ZoneEnd()
			return gameFramePost(self, frameNum)
		end
	end

	if not Script.GetSynced() then

	end
end

--------------------------------------------------------------------------------
--  Exports  -------------------------------------------------------------------

return {
	install  = install,
	getMarks = getMarks,
}
