
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Send Command",
		desc	= 'execute a console command for any player',
		author	= 'Floris',
		date	= 'march 2021',
		license	= 'GNU GPL, v2 or later',
		layer	= 1,
		enabled	= true
	}
end

-- usage: /luarules cmd playername disticon 900

local cmdname = 'cmd'
local PACKET_HEADER = "$c$"
local PACKET_HEADER_LENGTH = string.len(PACKET_HEADER)

if gadgetHandler:IsSyncedCode() then

	local startPlayers = {}
	function checkStartPlayers()
		for _,playerID in ipairs(Spring.GetPlayerList()) do -- update player infos
			local playername,_,spec = Spring.GetPlayerInfo(playerID,false)
			if not spec then
				startPlayers[playername] = true
			end
		end
	end
	function gadget:Initialize()
		checkStartPlayers()
	end
	function gadget:GameStart()
		checkStartPlayers()
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if string.sub(msg, 1, PACKET_HEADER_LENGTH) ~= PACKET_HEADER then
			return
		end
		local playername, _, spec, _, _, _, _, _, _, _, accountInfo = Spring.GetPlayerInfo(playerID)
		local accountID = (accountInfo and accountInfo.accountid) and tonumber(accountInfo.accountid) or -1
		local authorized = false
		if _G.permissions.cmd[accountID] then
			authorized = true
		end
		if authorized == nil then
			Spring.SendMessageToPlayer(playerID, "You are not authorized to send commands for a player")
			return
		elseif not spec then
			Spring.SendMessageToPlayer(playerID, "You arent allowed to send commands when playing")
			return
		elseif startPlayers[playername] ~= nil then
			Spring.SendMessageToPlayer(playerID, "You arent allowed to send commands when you have been a player")
			return
		end
		local params = string.split(msg, ':')
		SendToUnsynced("execCmd", params[2], params[3])
		return true
	end

else	-- UNSYNCED

	local myPlayerID = Spring.GetMyPlayerID()
	local _, _, _, _, _, _, _, _, _, _, accountInfo = Spring.GetPlayerInfo(myPlayerID)
	local accountID = (accountInfo and accountInfo.accountid) and tonumber(accountInfo.accountid) or -1
	local authorized = SYNCED.permissions.cmd[accountID]

	local function execCmd(_, playername, cmd)
		if playername == select(1, Spring.GetPlayerInfo(Spring.GetMyPlayerID())) or playername == '*' then
			Spring.SendCommands(cmd)
		end
	end

	local function RequestCmd(cmd, line, words, playerID)
		if authorized and playerID == myPlayerID then
			if words[1] ~= nil and words[2] ~= nil then
				local command = words[2]
				if #words > 2 then
					for k, v in ipairs(words) do
						if k >= 3 then
							command = command .. ' ' .. v
						end
					end
				end
				Spring.SendLuaRulesMsg(PACKET_HEADER..':'..words[1]..':'..command)
			else
				Spring.SendMessageToPlayer(playerID, "failed to execute, check syntax")
			end
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddChatAction(cmdname, RequestCmd)
		gadgetHandler:AddSyncAction("execCmd", execCmd)
	end
	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction(cmdname)
		gadgetHandler:AddSyncAction("execCmd")
	end
end

