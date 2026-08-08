local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Notifications Broadcaster",
        desc      = "Plays various voice notifications",
        author    = "Damgam, Floris",
        date      = "2025",
        license   = "GNU GPL, v2 or later",
        layer     = 5,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    function gadget:Initialize()
		gadgetHandler:AddSyncAction("NotificationEvent", BroadcastEvent)
	end

    function BroadcastEvent(_,event, player, forceplay, posx, posy, posz)
		if Script.LuaUI("NotificationEvent") and (forceplay or (tonumber(player) and ((tonumber(player) == Spring.GetMyPlayerID()) or Spring.GetSpectatingState()))) then
			if forceplay then
				forceplay = " y"
			else
				forceplay = ""
			end
            if posx and posy and posz then
			    Script.LuaUI.NotificationEvent(event .. " | " .. player .. " | " .. forceplay .. " | " .. posx .. " | " .. posy .. " | " .. posz)
            else
                Script.LuaUI.NotificationEvent(event .. " | " .. player .. " | " .. forceplay)
            end
		end
	end
end

GG["notifications"] = {}
---@param event string Notification event name (e.g., "commanderDetected", "EnemyCommanderDied"). Must match an event defined in sounds/voice/config.lua with properties: delay (integer), stackedDelay (bool), resetOtherEventDelay (string), soundEffect (string), notext (bool), tutorial (bool)
---@param idtype "playerID"|"teamID"|"allyTeamID"|nil Type of ID to target: "playerID" for specific player, "teamID" for all players on a team, "allyTeamID" for all players in an ally team, nil to send it to everyone.
---@param id number|string|nil PlayerID, TeamID, or AllyTeamID (converted to number internally)
---@param forceplay boolean|nil If true, skips spectator check and allows playing in pregame
---@param posx number|nil Position x
---@param posy number|nil Position y
---@param posz number|nil Position z
GG["notifications"].queueNotification =  function(event, idtype, id, forceplay, posx, posy, posz)
    local playerIDs = {}
    if not id then id = -1 end
    id = tonumber(id)

    if idtype == "playerID" then
        playerIDs[#playerIDs+1] = id
    elseif idtype == "teamID" then
        local playerList = Spring.GetPlayerList(id)
        for i = 1,#playerList do
            playerIDs[#playerIDs+1] = playerList[i]
        end
    elseif idtype == "allyTeamID" then
        local teamList = Spring.GetTeamList(id)
        for i = 1,#teamList do
            local playerList = Spring.GetPlayerList(teamList[i])
            for j = 1,#playerList do
                playerIDs[#playerIDs+1] = playerList[j]
            end
        end
    else
        local teamList = Spring.GetTeamList()
        for i = 1,#teamList do
            local playerList = Spring.GetPlayerList(teamList[i])
            for j = 1,#playerList do
                playerIDs[#playerIDs+1] = playerList[j]
            end
        end
    end

    if #playerIDs > 0 then
        for i = 1,#playerIDs do
            if gadgetHandler:IsSyncedCode() then
                SendToUnsynced("NotificationEvent", event, tostring(playerIDs[i]), forceplay, posx, posy, posz)
            else
                BroadcastEvent("NotificationEvent", event, tostring(playerIDs[i]), forceplay, posx, posy, posz)
            end
        end
    end
end