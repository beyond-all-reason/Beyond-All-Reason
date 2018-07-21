--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Get Player Data",
    desc      = "",
    author    = "Floris",
    date      = "July 2018",
    license   = "GNU GPL, v2 or later",
    layer     = 5,
    enabled   = true
  }
end

local devs = {
	["[teh]Flow"] = true,
	['FlowerPower'] = true,
	['Floris'] = true,
	['[Fx]Doo'] = true,
	['[PiRO]JiZaH'] = true,
	['Player'] = true,
}

if (gadgetHandler:IsSyncedCode()) then
	local charset = {}  do -- [0-9a-zA-Z]
		for c = 48, 57  do table.insert(charset, string.char(c)) end
		for c = 65, 90  do table.insert(charset, string.char(c)) end
		for c = 97, 122 do table.insert(charset, string.char(c)) end
	end
	local function randomString(length)
		if not length or length <= 0 then return '' end
		--math.randomseed(os.clock()^5)
		return randomString(length - 1) .. charset[math.random(1, #charset)]
	end
	local validation = randomString(2)
	_G.validationPlayerData = validation

	function gadget:RecvLuaMsg(msg, player)
		if msg:sub(1,2)=="pd" and msg:sub(3,4)==validation then
			local name = Spring.GetPlayerInfo(player)
			local data = string.sub(msg, 5)

			SendToUnsynced("SendToWG", name..";"..data)
			return true
		end
	end

else

	local validation = SYNCED.validationPlayerData

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("SendToWG", SendToWG)
	end

	function gadget:GotChatMsg(msg, player)
		local playername = Spring.GetPlayerInfo(player)
		if not devs[playername] then
			return
		end
		if string.sub(msg,1,9) == "getconfig" then
			local playerName = string.sub(msg, 11)
			if playerName == select(1, Spring.GetPlayerInfo(Spring.GetMyPlayerID())) then
				local config = VFS.LoadFile("LuaUI/Config/BA.lua")
				if config then
					config = string.sub(config, 1, 60000)
					Spring.SendLuaRulesMsg("pd"..validation.."config;"..config) --VFS.ZlibCompress(config))
				end
			end
		elseif string.sub(msg,1,10) == "getinfolog" then
			local playerName = string.sub(msg, 12)
			if playerName == select(1, Spring.GetPlayerInfo(Spring.GetMyPlayerID())) then
				local infolog = VFS.LoadFile("infolog.txt")
				if infolog then
					infolog = string.sub(infolog, 1, 30000)
					Spring.SendLuaRulesMsg("pd"..validation.."infolog;"..infolog) --VFS.ZlibCompress(infolog))
				end
			end
		end
	end

	function SendToWG(_,msg)
		local myplayername = Spring.GetPlayerInfo(Spring.GetMyPlayerID())
		if Script.LuaUI("PlayerDataBroadcast") then
			Script.LuaUI.PlayerDataBroadcast(myplayername, msg)
		end
		if devs[myplayername] then
			--Spring.Echo('PlayerDataBroadcast complete...')
		end
	end
end