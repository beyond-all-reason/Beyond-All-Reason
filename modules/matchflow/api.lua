--- Synced contract of the matchflow module: one owner of the match verdict.
--- Elimination, the scripted verdict and the ceremony all resolve through the
--- Game End gadget; contract includes are per-consumer, so this file holds no
--- state and forwards through that gadget's GG surface.

---@param name string
---@return table
local function gadgetSurface(name)
	local surface = GG.MatchFlow
	assert(surface ~= nil, "MatchFlow." .. name .. " called before the Game End gadget initialized")
	return surface
end

return {
	---Scripted victory: the given ally team wins. The verdict is taken on the
	---next tick; the ceremony still runs before the match actually ends.
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
