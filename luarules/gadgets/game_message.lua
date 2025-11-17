
local gadget = gadget ---@type Gadget

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
		SendToUnsynced("sendMsg", playerID, string.sub(msg, 4))
		return true
	end

else	-- UNSYNCED

	local function sendMsg(_, playerID, msg)
		local name,_,spec,_,playerAllyTeamID = Spring.GetPlayerInfo(playerID, false)
		local mySpec = Spring.GetSpectatingState()
		if not spec and (playerAllyTeamID == Spring.GetMyAllyTeamID() or mySpec) then
			Spring.SendMessageToPlayer(Spring.GetMyPlayerID(), '<'..name..'> Allies: > '..msg)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("sendMsg", sendMsg)
	end
	function gadget:Shutdown()
		gadgetHandler:AddSyncAction("sendMsg")
	end
end

