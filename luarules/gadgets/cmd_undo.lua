
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Undo Self Destruction Havoc",
		desc	= 'Restore selfdestructed units and the ones those killed (only availible to a select few playernames)',
		author	= 'Floris',
		date	= 'June 2017',
		license	= 'GNU GPL, v2 or later',
		layer	= 1,
		enabled	= false
	}
end

if (#SpringShared.GetTeamList())-1 <= 64 then
	return
end

-- usage: /luarules undo #teamid #maxSecondsAgo (#receivingteamid)

-- only works when being spectator and you werent a player before
-- only availible to a select few playernames

local cmdname = 'undo'

local rememberGameframes = 9000 -- 9000 -> 5 minutes
local mathFloor = math.floor

if gadgetHandler:IsSyncedCode() then
	local validation = string.randomString(2)
	_G.validationUndo = validation

	local teamSelfdUnits = {}
	local selfdCmdUnits = {}
	local lastSelfdTeamID = 0
	local sceduledRestoreHeightmap = {}

	local dgunDef = {}
	for weaponDefID, weaponDef in ipairs(WeaponDefs) do
		if weaponDef.type == 'DGun' then
			dgunDef[weaponDefID] = true
		end
	end

	local safeguardedUnits = {}
	local weaponUnitSelfd = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.customParams and tonumber(unitDef.customParams.techlevel) > 1 then
			if unitDef.isBuilding then
				safeguardedUnits[unitDefID] = true
			end
			if unitDef.metalMake > 0.5 or unitDef.energyMake > 5 or unitDef.energyUpkeep < 0 or unitDef.windGenerator > 0 or unitDef.customParams.solar or unitDef.tidalGenerator > 0 or unitDef.customParams.energyconv_capacity then
				safeguardedUnits[unitDefID] = true
			end
		end
		if unitDef.customParams.energyconv_capacity then
			safeguardedUnits[unitDefID] = true
		end
		if unitDef.selfDExplosion then
			local wDef = WeaponDefNames[unitDef.selfDExplosion]
			if wDef then
				weaponUnitSelfd[wDef.id] = unitDefID
			end
		end
	end

	local startPlayers = {}
	local function checkStartPlayers()
		for _,playerID in ipairs(SpringShared.GetPlayerList()) do -- update player infos
			local playername,_,spec,teamID = SpringShared.GetPlayerInfo(playerID,false)
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

	function gadget:GameFrame(gameFrame)
		-- cleanup periodically
		if gameFrame % 901 == 1 then
			local oldestGameFrame = gameFrame - rememberGameframes
			local cleanedUnits = {}
			for teamID, units in pairs(teamSelfdUnits) do
				cleanedUnits = {}
				for oldUnitID, params in pairs(units) do
					if params[1] > oldestGameFrame then
						cleanedUnits[oldUnitID] = params
					end
				end
				teamSelfdUnits[teamID] = cleanedUnits
			end
			cleanedUnits = {}
			local curGameframe = SpringShared.GetGameFrame()
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
				SpringSynced.RevertHeightMap(params[1], params[2], params[3], params[4], 1)
			end
			sceduledRestoreHeightmap[gameFrame] = nil
		end
	end

	function restoreUnits(teamID, seconds, toTeamID, playerID)
		if not SpringShared.GetTeamInfo(toTeamID,false) then
			return
		end
		if teamSelfdUnits[teamID] == nil then
			SpringUnsynced.SendMessageToPlayer(playerID, 'There is no self destruct unit history for team '..teamID)
			return
		end
		local oldestGameFrame = SpringShared.GetGameFrame() - (seconds * 30)
		local numRestoredUnits = 0
		local leftovers = {}
		for oldUnitID, params in pairs(teamSelfdUnits[teamID]) do
			if params[1] > oldestGameFrame then

				-- destroy old unit wreckage if any
				local features = SpringShared.GetFeaturesInCylinder(math.floor(params[4]),math.floor(params[6]),70)	-- using radius larger than 1 cause wreckage can fly off a bit
				for i=1,#features do
					local featureID = features[i]
					if UnitDefs[params[2]] ~= nil then
						local wreckName = UnitDefs[params[2]].wreckName
						if wreckName ~= nil and FeatureDefNames[wreckName] then
							local wreckageID = FeatureDefNames[wreckName].id
							if wreckageID ~= nil and wreckageID == SpringShared.GetFeatureDefID(featureID) then
								SpringSynced.DestroyFeature(featureID, false)
								break
							end
						end
					end
				end

				-- add unit
				local unitID = SpringSynced.CreateUnit(params[2], params[4], SpringShared.GetGroundHeight(params[4], params[6]), params[6], params[7], toTeamID)
				if unitID ~= nil then
					SpringSynced.SetUnitHealth(unitID, params[3])
					SpringSynced.SetUnitDirection(unitID, params[8], params[9], params[10])
					numRestoredUnits = numRestoredUnits + 1
				else
					leftovers[oldUnitID] = params
				end

				-- delay ground height restoration cause otherwise it just doesnt work properly
				if sceduledRestoreHeightmap[SpringShared.GetGameFrame() + 15] == nil then
					sceduledRestoreHeightmap[SpringShared.GetGameFrame() + 15] = {}
				end
				if UnitDefs[params[2]].selfDExplosion ~= nil then
					local radius = WeaponDefs[WeaponDefNames[UnitDefs[params[2]].selfDExplosion].id].damageAreaOfEffect
					if radius ~= nil then
						sceduledRestoreHeightmap[SpringShared.GetGameFrame() + 15][#sceduledRestoreHeightmap[SpringShared.GetGameFrame() + 15]+1] = {params[4]-radius, params[6]-radius, params[4]+radius, params[6]+radius}
						--table.insert(sceduledRestoreHeightmap[Spring.GetGameFrame() + 15], {params[4]-radius, params[6]-radius, params[4]+radius, params[6]+radius})
					end
				end
			else
				leftovers[oldUnitID] = params
			end
		end
		teamSelfdUnits[teamID] = leftovers
		SpringUnsynced.SendMessageToPlayer(playerID, 'Restored: '..numRestoredUnits..' units')
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if msg:sub(1,2)=="un" and msg:sub(3,4)==validation then

			local accountID = Spring.Utilities.GetAccountID(playerID)
			local authorized = false
			if _G.permissions.undo[accountID] then
				authorized = true
			end
			if authorized then
				local params = string.split(msg, ':')
				restoreUnits(tonumber(params[2]), tonumber(params[3]), tonumber(params[4]), playerID)
				return true
			end
		end
	end

	local function notify(message)
		for _,playerID in pairs(SpringShared.GetPlayerList()) do
			local accountID = Spring.Utilities.GetAccountID(playerID)
			if _G.permissions.undo[accountID] then
				SpringUnsynced.SendMessageToPlayer(playerID, message)
			end
		end
	end

	function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
		if safeguardedUnits[unitDefID] and attackerTeam and SpringShared.AreTeamsAllied(unitTeam, attackerTeam) then
			if dgunDef[weaponID] or weaponUnitSelfd[weaponID] or not SpringShared.GetUnitNearestEnemy(unitID, 1000) then
				local _, playerID, _, victimIsAi = SpringShared.GetTeamInfo(unitTeam, false)
				local name = SpringShared.GetPlayerInfo(playerID,false)
				if victimIsAi and SpringShared.GetGameRulesParam('ainame_' .. unitTeam) then
					name = SpringShared.GetGameRulesParam('ainame_' .. unitTeam)..' (AI)'
				end
				name = name or '---'
				local _, attackerPlayerID, _, attackerIsAi = SpringShared.GetTeamInfo(attackerTeam, false)
				local attackerName = SpringShared.GetPlayerInfo(attackerPlayerID,false)
				if attackerIsAi and SpringShared.GetGameRulesParam('ainame_' .. attackerTeam) then
					attackerName = SpringShared.GetGameRulesParam('ainame_' .. attackerTeam)..' (AI)'
				end
				attackerName = attackerName or '---'
				local x,_,z = SpringShared.GetUnitPosition(unitID)
				local unitName = UnitDefs[unitDefID].name
				local atPosition = not x and '' or "   (pos: "..math.floor(math.floor(x/100)*100)..", "..math.floor(math.floor(z/100)*100)..")"
				--if not attackerIsAi then
				if dgunDef[weaponID] then
					if name == attackerName then
						notify("\255\255\100\100 -- ALERT --   "..attackerName.." tried to DGUN their own "..unitName..atPosition)
					else
						notify("\255\255\100\100 -- ALERT --   "..attackerName.." tried to DGUN "..name.."'s "..unitName..atPosition)
					end
					return 0, 0
				elseif weaponUnitSelfd[weaponID] then
					if name == attackerName then
						notify("\255\255\100\100 -- ALERT --   "..attackerName.." tried to damage their own "..unitName.." (via a SELFD)"..atPosition)
					else
						notify("\255\255\100\100 -- ALERT --   "..attackerName.." tried to damage "..name.."'s "..unitName.." (via a SELFD)"..atPosition)
					end
					return 0, 0
				elseif not SpringShared.GetUnitNearestEnemy(unitID, 1000) then
					if name == attackerName then
						notify("\255\255\100\100 -- ALERT --   "..attackerName.." tried to damage their own "..unitName.." without nearby enemy"..atPosition)
					else
						notify("\255\255\100\100 -- ALERT --   "..attackerName.." tried to damage "..name.."'s "..unitName.." without nearby enemy"..atPosition)
					end
					return 0, 0
				end
				-- end
			end
		end
		return damage, 1
	end

	-- log selfd units and all the deaths they caused
	function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID, weaponDefID)
		if (attackerID == nil and selfdCmdUnits[unitID]) or (attackerID ~= nil and selfdCmdUnits[attackerID]) then -- attackerID == nil -> selfd/reclaim
			local ux,uy,uz = SpringShared.GetUnitPosition(unitID)
			local health, maxHealth = SpringShared.GetUnitHealth(unitID)
			local buildFacing =  SpringShared.GetUnitBuildFacing(unitID)
			local dx, dy, dz =  SpringShared.GetUnitDirection(unitID)
			if attackerID ~= nil then
				selfdCmdUnits[unitID] = SpringShared.GetGameFrame() - SpringShared.GetUnitSelfDTime(unitID)
				teamID = lastSelfdTeamID
				health = maxHealth	-- health only applicable to actual selfd units
			else
				lastSelfdTeamID = teamID
			end
			if teamSelfdUnits[teamID] == nil then
				teamSelfdUnits[teamID] = {}
			end
			teamSelfdUnits[teamID][unitID] = {SpringShared.GetGameFrame(), unitDefID, health, ux, uy, uz, buildFacing, dx, dy, dz}
		end
	end

	-- log selfd commands
	function gadget:UnitCommand(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)

		-- check for queued selfd (to check if queue gets cancelled)
		if selfdCmdUnits[unitID] then
			local foundSelfdCmd = false
			local unitQueue = SpringShared.GetUnitCommands(unitID,20) or {}
			if #unitQueue > 0 then
				for i=1, #unitQueue do
					local cmd = unitQueue[i]
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
			if SpringShared.GetUnitSelfDTime(unitID) > 0 then  	-- since cmd hasnt been cancelled yet
				selfdCmdUnits[unitID] = nil
			else
				selfdCmdUnits[unitID] = SpringShared.GetGameFrame()
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
			local targetTeamID = words[1]
			if words[3] ~= nil then
				targetTeamID = words[3]
			end
			SpringUnsynced.SendLuaRulesMsg('un'..validation..':'..words[1]..':'..words[2]..':'..targetTeamID)
		end
	end
end

