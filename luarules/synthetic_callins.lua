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

return syntheticCallinHold, callinHoldSummary
