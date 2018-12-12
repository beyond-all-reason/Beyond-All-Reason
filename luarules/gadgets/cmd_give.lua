
function gadget:GetInfo()
	return {
		name    = "Give Command",
		desc	= 'Give units (only availible to a select few playernames)',
		author	= 'Floris',
		date	= 'June 2017',
		license	= 'GNU GPL, v2 or later',
		layer	= 1,
		enabled	= true
	}
end


if (Game and Game.gameVersion and (string.find(Game.gameVersion, 'test') or string.find(Game.gameVersion, '$VERSION'))) then

	-- usage: /luarules give 1 armcom 0

	local cmdname = 'give'

	local PACKET_HEADER = "$g$"
	local PACKET_HEADER_LENGTH = string.len(PACKET_HEADER)

	local authorizedPlayers  = {'[teh]Flow', 'FlowerPower', 'Floris'}

	local isSilentUnitGift = {armstone=true, corstone=true, chip=true, dice=true, xmasball=true, xmasball2=true}

	if gadgetHandler:IsSyncedCode() then

		local startPlayers = {}
		function checkStartPlayers()
			for _,playerID in ipairs(Spring.GetPlayerList()) do -- update player infos
				local playername,_,spec,teamID = Spring.GetPlayerInfo(playerID)
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
		function gadget:PlayerChanged(playerID)
			checkStartPlayers()
		end

		function explode(div,str) -- credit: http://richard.warburton.it
			if (div=='') then return false end
			local pos,arr = 0,{}
			-- for each divider found
			for st,sp in function() return string.find(str,div,pos,true) end do
				table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
				pos = sp + 1 -- Jump past current divider
			end
			table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
			return arr
		end

		function giveunits(amount, unitName, teamID, x, z, playerID)
			local unitDefID
			for udid, unitDef in pairs(UnitDefs) do
				if unitDef.name == unitName then  unitDefID = udid break end
			end
			if unitDefID == nil then
				Spring.SendMessageToPlayer(playerID, "Unitname '"..unitName.."' isnt valid")
			else
				local succesfullyCreated = 0
				for i=1, amount do
					local unitID = Spring.CreateUnit(unitDefID, x, Spring.GetGroundHeight(x, z), z, 0, teamID)
					if unitID ~= nil then
						succesfullyCreated = succesfullyCreated + 1
					end
				end
				if succesfullyCreated > 0 then
					if isSilentUnitGift[unitName] == nil then
						Spring.SendMessageToTeam(teamID, "You have been given: "..succesfullyCreated.." "..unitName)
					end
					Spring.SendMessageToPlayer(playerID, "You have given team "..teamID..": "..succesfullyCreated.." "..unitName)
				end
			end
		end

		function gadget:RecvLuaMsg(msg, playerID)
			if string.sub(msg, 1, PACKET_HEADER_LENGTH) ~= PACKET_HEADER then
				return
			end

			local playername, _, spec = Spring.GetPlayerInfo(playerID)
			local authorized = false
			for _,name in ipairs(authorizedPlayers) do
				if playername == name then
					authorized = true
					break
				end
			end
			if playername ~= "UnnamedPlayer" then
				if authorized == nil then
					Spring.SendMessageToPlayer(playerID, "You are not authorized to give units")
					return
				end
				if not spec then
					Spring.SendMessageToPlayer(playerID, "You arent allowed to give units when playing")
					return
				end
				if startPlayers[playername] ~= nil then
					Spring.SendMessageToPlayer(playerID, "You arent allowed to give units when you have been a player")
					return
				end
			end
			local params = explode(':', msg)
			giveunits(tonumber(params[2]), params[3], tonumber(params[4]), tonumber(params[5]), tonumber(params[6]), playerID)
			return true
		end

		local function setGaiaUnitSpecifics(unitID)
			Spring.SetUnitNeutral(unitID, true)
			Spring.SetUnitNoSelect(unitID, true)
			Spring.SetUnitStealth(unitID, true)
			Spring.SetUnitNoMinimap(unitID, true)
			--Spring.SetUnitMaxHealth(unitID, 2)
			Spring.SetUnitBlocking(unitID, false)
			Spring.SetUnitSensorRadius(unitID, 'los', 0)
			Spring.SetUnitSensorRadius(unitID, 'airLos', 0)
			Spring.SetUnitSensorRadius(unitID, 'radar', 0)
			Spring.SetUnitSensorRadius(unitID, 'sonar', 0)
			for weaponID, _ in pairs(UnitDefs[Spring.GetUnitDefID(unitID)].weapons) do
				Spring.UnitWeaponHoldFire(unitID, weaponID)
			end
		end

		local isObjectUnit = {}
		if UnitDefNames['armstone'] ~= nil and UnitDefNames['corstone_bar'] ~= nil then
			isObjectUnit[UnitDefNames['armstone'].id] = true
			isObjectUnit[UnitDefNames['corstone'].id] = true
		end
		if UnitDefNames['armstone_bar'] ~= nil and UnitDefNames['corstone_bar'] ~= nil then
			isObjectUnit[UnitDefNames['armstone_bar'].id] = true
			isObjectUnit[UnitDefNames['corstone_bar'].id] = true
		end
		function gadget:UnitCreated(unitID, unitDefID, unitTeam)
			if isObjectUnit[unitDefID] then
				setGaiaUnitSpecifics(unitID)
			end
		end

	else	-- UNSYNCED


		function gadget:Initialize()
			gadgetHandler:AddChatAction(cmdname, RequestGive)
		end

		function gadget:Shutdown()
			gadgetHandler:RemoveChatAction(cmdname)
		end

		function RequestGive(cmd, line, words, playerID)
			local playername, _, spec = Spring.GetPlayerInfo(Spring.GetMyPlayerID())
			local authorized = false
			for _,name in ipairs(authorizedPlayers) do
				if playername == name or playername == "UnnamedPlayer" then
					authorized = true
					break
				end
			end
			if authorized then
				local mx,my = Spring.GetMouseState()
				local targettype,pos = Spring.TraceScreenRay(mx,my)
				if targettype == 'unit' then
					pos = {Spring.GetUnitPosition(pos)}
				elseif targettype == 'feature' then
					pos = {Spring.GetFeaturePosition(pos)}
				end
				if type(pos) == 'table' and pos[1] ~= nil and pos[3] ~= nil and pos[1] > 0 and pos[3] > 0 and words[1] ~= nil and words[2] ~= nil and words[3] ~= nil then
					Spring.SendLuaRulesMsg(PACKET_HEADER..':'..words[1]..':'..words[2]..':'..words[3]..':'..pos[1]..':'..pos[3])
				else
					Spring.SendMessageToPlayer(playerID, "failed to give, check syntax or cursor position")
				end
			end
		end
	end

end