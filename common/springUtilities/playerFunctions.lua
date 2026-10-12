---
--- Player utilities, including support for who controls the host.
---

-- Connected clients are behind always by a given latency plus max 16 frames between keyframes.
local LAGGING_PING_SECONDS = 3.0

local spGetPlayerList = Spring.GetPlayerList
local spGetPlayerInfo = Spring.GetPlayerInfo

---Whether the player is too far behind the game to act as controller. Reported by the server.
---@param playerID PlayerID
---@return boolean
local function isPlayerLagging(playerID)
	local pingTime = select(6, spGetPlayerInfo(playerID, false))
	return pingTime ~= nil and pingTime >= LAGGING_PING_SECONDS
end

---One player('s client) sends all commands that control or update the host for the game.
---
---Players are preferred to spectators, then current clients to lagging ones, then the lowest
---ping, and then the lowest player ID. All clients must reach an agreement on the controller.
---
---The server rejects commands from any spectator that does not currently host the game.
---@return PlayerID? playerID
local function getHostCommandPlayerID()
	local playerIDs = spGetPlayerList(true)
	if not playerIDs then
		return nil
	end

	local bestID, bestSpectator, bestLag
	for i = 1, #playerIDs do
		local playerID = playerIDs[i]
		local _, active, spectator, _, _, pingTime = spGetPlayerInfo(playerID, false)
		if active then
			local lag = pingTime >= LAGGING_PING_SECONDS and pingTime or 0
			if
				bestID == nil
				or (bestSpectator and not spectator)
				or (bestSpectator == spectator and (lag < bestLag or (lag == bestLag and playerID < bestID)))
			then
				bestID, bestSpectator, bestLag = playerID, spectator, lag
			end
		end
	end
	return bestID
end

return {
	GetHostCommandPlayerID = getHostCommandPlayerID,
	IsPlayerLagging = isPlayerLagging,
}
