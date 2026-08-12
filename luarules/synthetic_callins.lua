--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    synthetic_callins.lua
--  brief:   registry of the callins that gadgets.lua dispatches for itself
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--  Synthetic callins  ---------------------------------------------------------
--
--  These are artificially created within the game code to emulate the behaviors
--  of engine-driven callins. We are filling the gaps produced by the engine's
--  event system, in many cases, so code built on top of these foundations needs
--  to keep up with the times and adapt as the gaps fill in from the other side.
--
--  [IMPORTANT]
--  > Add each callin to the handler state that dispatches it, below.
--  >
--  > The engine does not know these names, so `Script.UpdateCallIn` is a no-op.
--  >
--  > Synthetic callins that subscribe to engine callins are kept installed for
--  > as long as anything subscribes to them. These _must_ be recorded here or
--  > can become unhooked whenever no addon happens to subscribe to their base.
--  >
--  > A synthetic callin that keeps per-frame state also needs an update hook in
--  > `syntheticCallinUpdate`, in gadgets.lua, next to the state it drops.

-- [HandlerState] := [SyntheticCallinName] := EngineCallinName[]
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
--  Build step marks  ----------------------------------------------------------
return syntheticCallinHold, callinHoldSummary

local unitStepMarked,    unitStepList,    unitStepCount    = {}, {}, {}
local featureStepMarked, featureStepList, featureStepCount = {}, {}, {}

local function dropUnitBuildStepMarks()
	for i = 1, unitStepCount[1] or 0 do
		unitStepMarked[unitStepList[i]] = nil
	end
	unitStepCount[1] = nil
end

local function dropFeatureBuildStepMarks()
	for i = 1, featureStepCount[1] or 0 do
		featureStepMarked[featureStepList[i]] = nil
	end
	featureStepCount[1] = nil
end

local syntheticCallinUpdate = {
	UnitBuildStepsPost = function(active)
		if active then
			unitStepCount[1] = unitStepCount[1] or 0
		else
			dropUnitBuildStepMarks()
		end
	end,
	FeatureBuildStepsPost = function(active)
		if active then
			featureStepCount[1] = featureStepCount[1] or 0
		else
			dropFeatureBuildStepMarks()
		end
	end,
}

--------------------------------------------------------------------------------
--  Dispatch  -------------------------------------------------------------------
--
--  We can attach to the gadgetHandler at load time, so callins are declared here.

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

return {
	hold              = syntheticCallinHold,   -- [SyntheticCallinName] := EngineCallinName[]
	holdSummary       = callinHoldSummary,     -- [EngineCallinName]    := SyntheticCallinListName[]
	update            = syntheticCallinUpdate, -- [SyntheticCallinName] := handleUpdateCallin

	unitStepMarked    = unitStepMarked,
	unitStepList      = unitStepList,
	unitStepCount     = unitStepCount,

	featureStepMarked = featureStepMarked,
	featureStepList   = featureStepList,
	featureStepCount  = featureStepCount,
}
