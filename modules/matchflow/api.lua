--- Synced contract of the matchflow module — DEMO-MINIMAL: the scripted-verdict
--- path only, not the game_end extraction (that is matchflow_module_plan.md,
--- later). The point of this file is the call shape: `MatchFlow.Victory(...)`
--- survives unchanged when the real module lands underneath it.
---
--- The pending verdict lives in the verdict gadget (one owner); contract
--- includes are per-consumer, so this file holds no state and forwards
--- through the gadget's GG surface.

---@param name string
---@return table
local function gadgetSurface(name)
	local surface = GG.MatchFlow
	assert(surface ~= nil, "MatchFlow." .. name .. " called before the matchflow_verdict gadget initialized")
	return surface
end

return {
	---Scripted victory: the given ally team wins on the next verdict tick.
	---@param allyTeamID integer
	Victory = function(allyTeamID)
		gadgetSurface("Victory").Victory(allyTeamID)
	end,

	---Scripted defeat: every other ally team (bar Gaia) wins.
	---@param allyTeamIDs integer[]
	Defeat = function(allyTeamIDs)
		gadgetSurface("Defeat").Defeat(allyTeamIDs)
	end,
}
