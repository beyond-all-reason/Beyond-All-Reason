
function gadget:GetInfo()
	return {
		name    = "Game Map Point",
		desc	= 'allow sending map points using the i18n library so everyone can see them in their own language',
		author	= 'Saurtron',
		date	= 'Oct 2024',
		license	= 'GNU GPL, v2 or later',
		layer	= 1,
		enabled	= true
	}
end

-- for example usecase see the ping_wheel widget createMapPoint and MapPointEvent methods

local PACKET_HEADER = "mppnt:"
local PACKET_HEADER_LENGTH = string.len(PACKET_HEADER)

if gadgetHandler:IsSyncedCode() then

	function gadget:RecvLuaMsg(msg, playerID)
		if string.sub(msg, 1, PACKET_HEADER_LENGTH) ~= PACKET_HEADER then
			return
		end
		SendToUnsynced("sendMapPoint", playerID, string.sub(msg, PACKET_HEADER_LENGTH+1))
		return true
	end

else	-- UNSYNCED

	local function sendMapPoint(_, playerID, msg)
		local name,_,spec,_,playerAllyTeamID = Spring.GetPlayerInfo(playerID)
		local mySpec = Spring.GetSpectatingState()
		if playerAllyTeamID == Spring.GetMyAllyTeamID() or mySpec then
			if Script.LuaUI("MapPointEvent") then
				Script.LuaUI.MapPointEvent(playerID, msg)
			end
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("sendMapPoint", sendMapPoint)
	end
	function gadget:Shutdown()
		gadgetHandler:AddSyncAction("sendMapPoint")
	end
end

