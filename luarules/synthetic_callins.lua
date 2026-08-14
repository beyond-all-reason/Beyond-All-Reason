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
--  This also produces two types of summary view of a base callin:
--  1. *Post.* This is a mark-and-sweep pattern to update dirtied IDs.
--  2. *Total.* This is an accumulator with a hook for custom results.
--
--  Adding a new callin:
--  1. Add the callin's envs and subscriptions to syntheticCallins.
--  2. If producing a summary view, add to syntheticCallinSummaries.
--     This produces both the <Base>Post and <Base>Total callins and
--     adds the custom GG.Accumulate<Base> hook later during install.
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
-- Update handlers receive the gadgetHandler to read their subscriber lists.
local syntheticCallinUpdate = {}

--------------------------------------------------------------------------------
--  Callin summary views  ------------------------------------------------------

local syntheticCallinSummaries = {
	UnitBuildStep    = true,
	FeatureBuildStep = true,
}

-- [baseName] := { marked, list, count, totals, active, stop }
local marks = {}

local function makeStopMarking(marked, list, count)
	return function()
		for i = 1, count[1] or 0 do
			marked[list[i]] = nil
		end
		count[1] = nil
	end
end

local accumulate = {}

local function createSummary(callinName)
	if not syntheticCallinSummaries[callinName] then
		return
	end

	local marked, list, count = {}, {}, table.new(1, 0)
	local totals, active = {}, table.new(1, 0)
	local stop = makeStopMarking(marked, list, count)

	marks[callinName] = { marked = marked, list = list, count = count, totals = totals, active = active, stop = stop }

	accumulate['Accumulate' .. callinName] = function(id, amount)
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
	local postList = callinName .. 'PostList'
	local totalList = callinName .. 'TotalList'
	local function update(gh)
		if #gh[totalList] > 0 then
			active[1] = true
		elseif active[1] then
			for i = 1, count[1] or 0 do
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
	syntheticCallinUpdate[callinName .. 'Post'] = update
	syntheticCallinUpdate[callinName .. 'Total'] = update
end

-- baseName -> marked, list, count, totals, active
local function getMarks(baseName)
	local mark = marks[baseName]
	if not mark then
		return
	end
	return mark.marked, mark.list, mark.count, mark.totals, mark.active
end

local function getMarksUnsafe(baseName)
	local mark = marks[baseName]
	return mark.marked, mark.list, mark.count, mark.totals, mark.active
end

--------------------------------------------------------------------------------
--  Dispatch  ------------------------------------------------------------------
--
--  The gadgetHandler is available at load time, so we implement callins here.
--  
--  - UnitAutoTargetRange has its base implementation in gadgets.lua, instead.

-- Installer contexts

local sweepUnitBuildStep
local sweepFeatureBuildStep

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
	createSummary('UnitBuildStep')
	local unitStepMarked, unitStepList, unitStepCount, unitStepTotals, unitStepActive = getMarksUnsafe('UnitBuildStep')
	local unitStepValues = {}

	function sweepUnitBuildStep(handler, frameNum)
		local count = unitStepCount[1]
		if not count or count == 0 then
			return
		end

		-- Clear marks first so subscribers that throw do not leave any marks.
		-- The count holds through dispatch so re-marks append past the batch.
		if unitStepActive[1] then
			for i = 1, count do
				local unitID = unitStepList[i]
				unitStepValues[i] = unitStepTotals[unitID] or 0
				unitStepTotals[unitID] = nil
				unitStepMarked[unitID] = nil
			end
		else
			for i = 1, count do
				unitStepMarked[unitStepList[i]] = nil
			end
		end

		-- Each subscriber receives the full batch at once, in layer order.
		-- This is an optimization that scales into much higher event counts.
		for _, g in ipairs(handler.UnitBuildStepPostList) do
			g:UnitBuildStepPost(unitStepList, count, frameNum)
		end
		for _, g in ipairs(handler.UnitBuildStepTotalList) do
			g:UnitBuildStepTotal(unitStepList, unitStepValues, count, frameNum)
		end

		-- Shift any re-marks made during dispatch into the next batch.
		local marked = unitStepCount[1]
		if marked and marked > count then
			for i = 1, marked - count do
				unitStepList[i] = unitStepList[count + i]
			end
			unitStepCount[1] = marked - count
		elseif marked then
			unitStepCount[1] = 0
		end
	end

	createSummary('FeatureBuildStep')
	local featureStepMarked, featureStepList, featureStepCount, featureStepTotals, featureStepActive = getMarksUnsafe('FeatureBuildStep')
	local featureStepValues = {}

	function sweepFeatureBuildStep(handler, frameNum)
		local count = featureStepCount[1]
		if not count or count == 0 then
			return
		end

		-- Clear marks first so subscribers that throw do not leave any marks.
		-- The count holds through dispatch so re-marks append past the batch.
		if featureStepActive[1] then
			for i = 1, count do
				local featureID = featureStepList[i]
				featureStepValues[i] = featureStepTotals[featureID] or 0
				featureStepTotals[featureID] = nil
				featureStepMarked[featureID] = nil
			end
		else
			for i = 1, count do
				featureStepMarked[featureStepList[i]] = nil
			end
		end

		for _, g in ipairs(handler.FeatureBuildStepPostList) do
			g:FeatureBuildStepPost(featureStepList, count, frameNum)
		end
		for _, g in ipairs(handler.FeatureBuildStepTotalList) do
			g:FeatureBuildStepTotal(featureStepList, featureStepValues, count, frameNum)
		end

		-- Shift any re-marks made during dispatch into the next batch.
		local marked = featureStepCount[1]
		if marked and marked > count then
			for i = 1, marked - count do
				featureStepList[i] = featureStepList[count + i]
			end
			featureStepCount[1] = marked - count
		elseif marked then
			featureStepCount[1] = 0
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
			handleUpdate(self)
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
			sweepUnitBuildStep(self, frameNum)
			sweepFeatureBuildStep(self, frameNum)
			tracy.ZoneEnd()
			return gameFramePost(self, frameNum)
		end

		for name, hook in pairs(accumulate) do
			gh.GG[name] = hook
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
