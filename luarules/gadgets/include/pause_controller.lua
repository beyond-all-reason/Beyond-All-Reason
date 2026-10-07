---
--- The one player whose client speaks for a scripted pause.
---

local spGetPlayerList = Spring.GetPlayerList
local spGetPlayerInfo = Spring.GetPlayerInfo

-- The lowest-numbered active, non-spectating player. Falls back to the
-- lowest-numbered active player when everybody spectates (the server only
-- accepts a spectator's pause when they host, which covers watching a
-- singleplayer mission).
local function getPauseControllerID()
	local playerIDs = spGetPlayerList(true)
	if not playerIDs or #playerIDs == 0 then
		return nil
	end
	for i = 1, #playerIDs do
		local playerID = playerIDs[i]
		local _, active, spectator = spGetPlayerInfo(playerID, false)
		if active and not spectator then
			return playerID
		end
	end
	return playerIDs[1]
end

return {
	GetPauseControllerID = getPauseControllerID,
}
