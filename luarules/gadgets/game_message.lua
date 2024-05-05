
function gadget:GetInfo()
	return {
		name    = "Message",
		desc	= 'allow sending messages using the i18n library so everyone can see them in their own language',
		author	= 'Floris',
		date	= 'May 2024',
		license	= 'GNU GPL, v2 or later',
		layer	= 1,
		enabled	= true
	}
end

-- example usecase: Spring.SendLuaRulesMsg('msg:ui.playersList.chat.needEnergyAmount:amount='..shareAmount)

local PACKET_HEADER = "msg"
local PACKET_HEADER_LENGTH = string.len(PACKET_HEADER)

if gadgetHandler:IsSyncedCode() then

	function gadget:RecvLuaMsg(msg, playerID)
		if string.sub(msg, 1, PACKET_HEADER_LENGTH) ~= PACKET_HEADER then
			return
		end
		local _, _, _, _, allyTeamID = Spring.GetPlayerInfo(playerID)
		for ct, id in pairs (Spring.GetTeamList(allyTeamID)) do
			SendToUnsynced("sendMsg", playerID, string.sub(msg, 4))
		end
		return true
	end

else	-- UNSYNCED

	local function sendMsg(_, playerID, msg)
		local name = Spring.GetPlayerInfo(playerID)
		Spring.SendMessageToPlayer(Spring.GetMyPlayerID(), '<'..name..'> Allies: > '..msg)
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("sendMsg", sendMsg)
	end
	function gadget:Shutdown()
		gadgetHandler:AddSyncAction("sendMsg")
	end
end

