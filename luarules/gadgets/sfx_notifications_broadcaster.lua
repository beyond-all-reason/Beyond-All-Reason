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

    ---@param _ number Sync action ID (ignored)
    ---@param event string Notification event name (e.g., "commanderDetected", "EnemyCommanderDied"). Must match an event defined in sounds/voice/config.lua
    ---@param player string|number Player ID as string or number
    ---@param forceplay boolean|nil If true, forces the notification to play regardless of player filtering
    function BroadcastEvent(_,event, player, forceplay)
		if Script.LuaUI("NotificationEvent") and (forceplay or (tonumber(player) and ((tonumber(player) == Spring.GetMyPlayerID()) or Spring.GetSpectatingState()))) then
			if forceplay then
				forceplay = " y"
			else
				forceplay = ""
			end
			Script.LuaUI.NotificationEvent(event .. " " .. player .. forceplay)
		end
	end
end

GG["notifications"] = {}
---@param event string Notification event name (e.g., "commanderDetected", "EnemyCommanderDied"). Must match an event defined in sounds/voice/config.lua with properties: delay (integer), stackedDelay (bool), resetOtherEventDelay (string), soundEffect (string), notext (bool), tutorial (bool)
---@param idtype "playerID"|"teamID"|"allyTeamID" Type of ID to target: "playerID" for specific player, "teamID" for all players on a team, "allyTeamID" for all players in an ally team
---@param id number|string PlayerID, TeamID, or AllyTeamID (converted to number internally)
---@param forceplay boolean|nil If true, forces the notification to play regardless of player filtering and cooldown delays
GG["notifications"].queueNotification = function(event, idtype, id, forceplay)
    local playerIDs = {}
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
    end

    if #playerIDs > 0 then
        for i = 1,#playerIDs do
            if gadgetHandler:IsSyncedCode() then
                SendToUnsynced("NotificationEvent", event, tostring(playerIDs[i]), forceplay)
            else
                BroadcastEvent("NotificationEvent", event, tostring(playerIDs[i]), forceplay)
            end
        end
    end
end