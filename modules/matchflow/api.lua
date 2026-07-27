---@param name string
---@return table
local function gadgetSurface(name)
	local surface = GG.MatchFlow
	assert(surface ~= nil, "MatchFlow." .. name .. " called before the Game End gadget initialized")
	return surface
end

return {
	---@param allyTeamID integer
	Victory = function(allyTeamID)
		gadgetSurface("Victory").Victory(allyTeamID)
	end,

	---@param allyTeamIDs integer[]
	Defeat = function(allyTeamIDs)
		gadgetSurface("Defeat").Defeat(allyTeamIDs)
	end,
}
