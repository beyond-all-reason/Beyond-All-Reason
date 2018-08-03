
function gadget:GetInfo()
	return {
		name    = "Undo Self Destruction Havoc",
		desc	= 'Restore selfdestructed units and the ones those killed (only availible to a select few playernames)',
		author	= 'Floris',
		date	= 'June 2017',
		license	= 'GNU GPL, v2 or later',
		layer	= 1,
		enabled	= true
	}
end

-- usage: /luarules undo #teamid #maxSecondsAgo (#receivingteamid)

-- only works when being spectator and you werent a player before
-- only availible to a select few playernames.... (listed in var: authorizedPlayers)

local cmdname = 'undo'

local rememberGameframes = 9000 -- 9000 -> 5 minutes

if gadgetHandler:IsSyncedCode() then
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
	_G.validationUndo = validation


	local authorizedPlayers  = {
		'[teh]Flow',
		'Floris',
		'FlowerPower',
		'[Fx]Doo',
		'[PiRO]JiZaH',
	}

	local teamSelfdUnits = {}
	local selfdCmdUnits = {}
	local lastSelfdTeamID = 0
	local sceduledRestoreHeightmap = {}

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

	function gadget:GameFrame(gameFrame)
		-- cleanup periodically
		if gameFrame % 901 == 1 then
			local oldestGameFrame = gameFrame - rememberGameframes
			for teamID, units in pairs(teamSelfdUnits) do
				local cleanedUnits = {}
				for oldUnitID, params in pairs(units) do
					if params[1] > oldestGameFrame then
						cleanedUnits[oldUnitID] = params
					end
				end
				teamSelfdUnits[teamID] = cleanedUnits
			end
			cleanedUnits = {}
			local curGameframe = Spring.GetGameFrame()
			for unitID, gameframe in pairs(selfdCmdUnits) do
				if gameframe > curGameframe - 30 then
					cleanedUnits[unitID] = gameframe
				end
			end
			selfdCmdUnits = cleanedUnits
		end
		-- apply sceduled heightmap restoration
		if sceduledRestoreHeightmap[gameFrame] ~= nil then
			for i, params in pairs(sceduledRestoreHeightmap[gameFrame]) do
				Spring.RevertHeightMap(params[1], params[2], params[3], params[4], 1)
			end
			sceduledRestoreHeightmap[gameFrame] = nil
		end
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

	function restoreUnits(teamID, seconds, toTeamID, playerID)
		if not Spring.GetTeamInfo(toTeamID) then
			return
		end
		if teamSelfdUnits[teamID] == nil then
			Spring.SendMessageToPlayer(playerID, 'There is no self destruct unit history for team '..teamID)
			return
		end
		local oldestGameFrame = Spring.GetGameFrame() - (seconds * 30)
		local numRestoredUnits = 0
		local leftovers = {}
		for oldUnitID, params in pairs(teamSelfdUnits[teamID]) do
			if params[1] > oldestGameFrame then

				-- destroy old unit wreckage if any
				local features = Spring.GetFeaturesInCylinder(math.floor(params[4]),math.floor(params[6]),70)	-- using radius larger than 1 cause wreckage can fly off a bit
				for i, featureID in pairs(features) do
					if UnitDefs[params[2]] ~= nil then
						local wreckName = UnitDefs[params[2]].wreckName
						if wreckName ~= nil then
							local wreckageID = FeatureDefNames[wreckName].id
							if wreckageID ~= nil and wreckageID == Spring.GetFeatureDefID(featureID) then
								Spring.DestroyFeature(featureID, false)
								break
							end
						end
					end
				end

				-- add unit
				local unitID = Spring.CreateUnit(params[2], params[4], Spring.GetGroundHeight(params[4], params[6]), params[6], params[7], toTeamID)
				if unitID ~= nil then
					Spring.SetUnitHealth(unitID, params[3])
					Spring.SetUnitDirection(unitID, params[8], params[9], params[10])
					numRestoredUnits = numRestoredUnits + 1
				else
					leftovers[oldUnitID] = params
				end

				-- delay ground height restoration cause otherwise it just doesnt work properly
				if sceduledRestoreHeightmap[Spring.GetGameFrame() + 15] == nil then
					sceduledRestoreHeightmap[Spring.GetGameFrame() + 15] = {}
				end
				if UnitDefs[params[2]].selfDExplosion ~= nil then
					local radius = WeaponDefs[WeaponDefNames[UnitDefs[params[2]].selfDExplosion].id].damageAreaOfEffect
					if radius ~= nil then
						sceduledRestoreHeightmap[Spring.GetGameFrame() + 15][#sceduledRestoreHeightmap[Spring.GetGameFrame() + 15]+1] = {params[4]-radius, params[6]-radius, params[4]+radius, params[6]+radius}
						--table.insert(sceduledRestoreHeightmap[Spring.GetGameFrame() + 15], {params[4]-radius, params[6]-radius, params[4]+radius, params[6]+radius})
					end
				end
			else
				leftovers[oldUnitID] = params
			end
		end
		teamSelfdUnits[teamID] = leftovers
		Spring.SendMessageToPlayer(playerID, 'Restored: '..numRestoredUnits..' units')
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if msg:sub(1,2)=="un" and msg:sub(3,4)==validation then

			local playername, _, spec = Spring.GetPlayerInfo(playerID)
			local authorized = false
			for _,name in ipairs(authorizedPlayers) do
				if playername == name then
					authorized = true
					break
				end
			end
			if playername ~= "UnnamedPlayer" then
				if not authorized then
					--Spring.SendMessageToPlayer(playerID, "You are not authorized to restore units")
					return
				end
				if authorized and not spec then
					Spring.SendMessageToPlayer(playerID, "You arent allowed to restore units when playing")
					return
				end
				if startPlayers[playername] ~= nil then
					Spring.SendMessageToPlayer(playerID, "You arent allowed to restore units when you have been a player")
					return
				end
			end
			local params = explode(':', msg)
			restoreUnits(tonumber(params[2]), tonumber(params[3]), tonumber(params[4]), playerID)
			return true
		end
	end


	-- log selfd units and all the deaths they caused
	function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
		if (attackerID == nil and selfdCmdUnits[unitID]) or (attackerID ~= nil and selfdCmdUnits[attackerID])  then -- attackerID == nil -> selfd/reclaim
			local ux,uy,uz = Spring.GetUnitPosition(unitID)
			local health, maxHealth = Spring.GetUnitHealth(unitID)
			local buildFacing =  Spring.GetUnitBuildFacing(unitID)
			local dx, dy, dz =  Spring.GetUnitDirection(unitID)
			if attackerID ~= nil then
				selfdCmdUnits[unitID] = Spring.GetGameFrame() - Spring.GetUnitSelfDTime(unitID)
				teamID = lastSelfdTeamID
				health = maxHealth	-- health only applicable to actual selfd units
			else
				lastSelfdTeamID = teamID
			end
			if teamSelfdUnits[teamID] == nil then
				teamSelfdUnits[teamID] = {}
			end
			teamSelfdUnits[teamID][unitID] = {Spring.GetGameFrame(), unitDefID, health, ux, uy, uz, buildFacing, dx, dy, dz}
		end
	end

	-- log selfd commands
	function gadget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)

		-- check for queued selfd (to check if queue gets cancelled)
		if selfdCmdUnits[unitID] then
			local foundSelfdCmd = false
			local unitQueue = Spring.GetUnitCommands(unitID,20) or {}
			if (#unitQueue > 0) then
				for _,cmd in ipairs(unitQueue) do
					if cmd.id == CMD.SELFD then
						foundSelfdCmd = true
						break
					end
				end
			end
			if foundSelfdCmd then
				selfdCmdUnits[unitID] = nil
			end
		end

		if cmdID == CMD.SELFD then
			if Spring.GetUnitSelfDTime(unitID) > 0 then  	-- since cmd hasnt been cancelled yet
				selfdCmdUnits[unitID] = nil
			else
				selfdCmdUnits[unitID] = Spring.GetGameFrame()
			end
		end
	end

else	-- UNSYNCED

	local validation = SYNCED.validationUndo

	function gadget:Initialize()
		gadgetHandler:AddChatAction(cmdname, Undo)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction(cmdname)
	end

	function Undo(cmd, line, words, playerID)
		if words[1] ~= nil and words[2] ~= nil then
			targetTeamID = words[1]
			if words[3] ~= nil then
				targetTeamID = words[3]
			end
			Spring.SendLuaRulesMsg('un'..validation..':'..words[1]..':'..words[2]..':'..targetTeamID)
		end
	end
end

