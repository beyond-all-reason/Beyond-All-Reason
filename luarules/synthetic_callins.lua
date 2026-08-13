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
--  3. If the callin tracks any state, add it to syntheticCallinUpdate.
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
		UnitBuildStepsPost    = { 'GameFramePost', 'AllowUnitBuildStep' },
		FeatureBuildStepsPost = { 'GameFramePost', 'AllowFeatureBuildStep' },
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

--------------------------------------------------------------------------------
--  Callin mark-and-sweep  -----------------------------------------------------
--  
--  Entries below gain the `prefixMarked`, `prefixList` and `prefixCount` tables
--  and a pair of functions for dropping swept-up marks and updating the callin.
--  These are exported with the module / included wherever the file is required.

-- [SyntheticCallinName] := markPrefix
local syntheticCallinMarks = {
	UnitBuildStepsPost    = 'unitStep',
	FeatureBuildStepsPost = 'featureStep',
}

local function makeDropMarks(marked, list, count)
	return function()
		for i = 1, count[1] or 0 do
			marked[list[i]] = nil
		end
		count[1] = nil
	end
end

-- [markPrefix] := { marked, list, count, drop }
local marks = {}

-- The engine does not know these names, so `Script.UpdateCallIn` is a no-op.
-- We have to handle dropping tracked state, etc., during updates on our own.
local syntheticCallinUpdate = {}

for name, prefix in pairs(syntheticCallinMarks) do
	local marked, list, count = {}, {}, { nil } -- luahax: a constant-size array
	local drop = makeDropMarks(marked, list, count)

	marks[prefix] = { marked = marked, list = list, count = count, drop = drop }

	syntheticCallinUpdate[name] = function(active)
		if active then
			count[1] = count[1] or 0
		else
			drop()
		end
	end
end

-- markPrefix -> marked, list, count
local function getMarks(prefix)
	local mark = marks[prefix]
	assert(mark, "synthetic_callins: no marks configured for '" .. tostring(prefix) .. "'")
	return mark.marked, mark.list, mark.count
end

--------------------------------------------------------------------------------
--  Dispatch  ------------------------------------------------------------------
--
--  The gadgetHandler is available at load time, so we implement callins here.
--  
--  - UnitAutoTargetRange has its base implementation in gadgets.lua, instead.

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

local unitStepMarked, unitStepList, unitStepCount = getMarks('unitStep')

function gadgetHandler:UnitBuildStepsPost()
	local count = unitStepCount[1]
	if not count or count == 0 then
		return
	end
	unitStepCount[1] = 0

	-- Clear marks first so a subscriber that throws does not leave any marks.
	for i = 1, count do
		unitStepMarked[unitStepList[i]] = nil
	end

	local list = self.UnitBuildStepsPostList
	for i = 1, count do
		local unitID = unitStepList[i]
		for _, g in ipairs(list) do
			g:UnitBuildStepsPost(unitID)
		end
	end
end

local featureStepMarked, featureStepList, featureStepCount = getMarks('featureStep')

function gadgetHandler:FeatureBuildStepsPost()
	local count = featureStepCount[1]
	if not count or count == 0 then
		return
	end
	featureStepCount[1] = 0

	-- Clear marks first so a subscriber that throws does not leave any marks.
	for i = 1, count do
		featureStepMarked[featureStepList[i]] = nil
	end

	local list = self.FeatureBuildStepsPostList
	for i = 1, count do
		local featureID = featureStepList[i]
		for _, g in ipairs(list) do
			g:FeatureBuildStepsPost(featureID)
		end
	end
end

--------------------------------------------------------------------------------
--  Exports  -------------------------------------------------------------------

return {
	hold        = syntheticCallinHold,   -- [SyntheticCallinName] := EngineCallinName[]
	holdSummary = callinHoldSummary,     -- [EngineCallinName]    := SyntheticCallinListName[]
	update      = syntheticCallinUpdate, -- [SyntheticCallinName] := handleUpdateCallin
	getMarks    = getMarks,              -- markPrefix -> marked, list, count
}
