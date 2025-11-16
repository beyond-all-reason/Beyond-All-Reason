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