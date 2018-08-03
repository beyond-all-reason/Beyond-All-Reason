
function gadget:GetInfo()
	return {
		name    = "Kick Command",
		desc	= 'Kick a player from the game',
		author	= 'Floris',
		date	= 'August 2018',
		license	= 'GNU GPL, v2 or later',
		layer	= 1,
		enabled	= true
	}
end


local authorized = {
	["[teh]Flow"] = true,
	['FlowerPower'] = true,
	['Floris'] = true,
	['[Fx]Doo'] = true,
	['[PiRO]JiZaH'] = true,
	['[Fx]Bluestone'] = true,
	['[PinK]Triton'] = true,
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
	_G.validationKick = validation

	function gadget:RecvLuaMsg(msg, player)
		if msg:sub(1,2)=="kk" and msg:sub(3,4)==validation then
			local playername = string.sub(msg, 5)
			SendToUnsynced("kickplayer", playername)
			return true
		end
	end

else

	local validation = SYNCED.validationKick
	local myPlayerName = Spring.GetPlayerInfo(Spring.GetMyPlayerID())

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("kickplayer", kickplayer)
	end

	function gadget:GotChatMsg(msg, player)
		local myPlayerName = Spring.GetPlayerInfo(player)
		if not authorized[myPlayerName] then
			return
		end
		if string.sub(msg,1,4) == "kick" then
			local playerName = string.sub(msg, 6)
			if playerName == select(1, Spring.GetPlayerInfo(Spring.GetMyPlayerID())) then
				Spring.SendLuaRulesMsg('kk'..validation..playerName)
			end
		end
	end

	function kickplayer(_,playername)
		if playername == myPlayerName then
			Spring.SendCommands('QuitForce')
		end
	end

end