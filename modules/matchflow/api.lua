
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

	---@param allyTeamIDs integer[]
	Defeat = function(allyTeamIDs)
		gadgetSurface("Defeat").Defeat(allyTeamIDs)
	end,
}
