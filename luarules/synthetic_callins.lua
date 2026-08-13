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
--  2. If using mark-and-sweep, add the callin to syntheticCallinMarks.
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
		UnitBuildStepPost    = { 'GameFramePost', 'AllowUnitBuildStep' },
		FeatureBuildStepPost = { 'GameFramePost', 'AllowFeatureBuildStep' },
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
		local lists = callinHoldSummary[callin]
		if not lists then
			lists = {}
			callinHoldSummary[callin] = lists
		end
		lists[#lists + 1] = name .. 'List'
	end
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

local function createMarks(callinName)
	local prefix = syntheticCallinMarks[callinName]
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

		local list = self.UnitBuildStepPostList
		for i = 1, count do
			local unitID = unitStepList[i]
			for _, g in ipairs(list) do
				g:UnitBuildStepPost(unitID)
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

		local list = self.FeatureBuildStepPostList
		for i = 1, count do
			local featureID = featureStepList[i]
			for _, g in ipairs(list) do
				g:FeatureBuildStepPost(featureID)
			end
		end
	end
end

-- Unsynced environment

if not Script.GetSynced() then

end

--------------------------------------------------------------------------------
--  Exports  -------------------------------------------------------------------

return {
	hold        = syntheticCallinHold,   -- [SyntheticCallinName] := EngineCallinName[]
	holdSummary = callinHoldSummary,     -- [EngineCallinName]    := SyntheticCallinListName[]
	update      = syntheticCallinUpdate, -- [SyntheticCallinName] := handleUpdateCallin
	getMarks    = getMarks,              -- markPrefix -> marked, list, count
}
