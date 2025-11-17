local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Notifications",
        desc      = "Plays various voice notifications",
        author    = "Doo, Floris",
        date      = "2018",
        license   = "GNU GPL, v2 or later",
        version   = 1,
        layer     = 5,
        enabled   = true
    }
end

local spGetPlayerInfo = Spring.GetPlayerInfo

local function GetAllyTeamID(teamID)
	return select(6,Spring.GetTeamInfo(teamID,false))
end

local function PlayersInAllyTeamID(allyTeamID)
	local players = Spring.GetPlayerList()
	local _,_,spec,_,allyTeam
	for ct, id in pairs(players) do
		_,_,spec,_,allyTeam = spGetPlayerInfo(id,false)
		if not spec and allyTeam ~= allyTeamID then
			players[ct] = nil
		end
	end
	return players
end

local function AllButAllyTeamID(allyTeamID)
	local players = Spring.GetPlayerList()
	local _,_,spec,_,allyTeam
	for ct, id in pairs(players) do
		_,_,spec,_,allyTeam = spGetPlayerInfo(id,false)
		if not spec and allyTeam == allyTeamID then
			players[ct] = nil
		end
	end
	return players
end

if gadgetHandler:IsSyncedCode() then

	local isT2Mex = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		-- not critter/raptor/object
		if not string.find(unitDef.name, 'critter') and not string.find(unitDef.name, 'raptor') and (not unitDef.modCategories or not unitDef.modCategories.object) then
			if unitDef.extractsMetal >= 0.004 then
				isT2Mex[unitDefID] = unitDef.extractsMetal
			end
		end
	end
	local nukeWeapons = {}
	for id, def in pairs(WeaponDefs) do
		if def.targetable and def.targetable == 1 then
			if def.name ~= "raptor_allterrain_arty_basic_t4_v1_meteorlauncher" then	-- to not drive them mad
				nukeWeapons[id] = true
			end
		end
	end

	function gadget:Initialize()
		for k,v in pairs(nukeWeapons) do
			Script.SetWatchProjectile(k, true)
		end
	end

	-- UNITS RECEIVED send to all in team
	function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
		if not _G.transferredUnits or not _G.transferredUnits[unitID] then	-- exclude upgraded units (t2 mex/geo) because allied players could have done this
			local players = Spring.GetPlayerList(newTeam)
			for ct, player in pairs (players) do
				if tostring(player) then
					if GetAllyTeamID(newTeam) == GetAllyTeamID(oldTeam) then -- We got it from a teammate
						GG["notifications"].queueNotification("UnitsReceived", "playerID", tostring(player))
					else  -- We got it from an enemy
						GG["notifications"].queueNotification("UnitsCaptured", "playerID", tostring(player))
					end
				end
			end
		end
	end

	-- NUKE LAUNCH send to all but ally team
	function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
		if nukeWeapons[Spring.GetProjectileDefID(proID)] then
			local players = AllButAllyTeamID(GetAllyTeamID(Spring.GetUnitTeam(proOwnerID)))
			for ct, player in pairs (players) do
				if tostring(player) then
					GG["notifications"].queueNotification("NukeLaunched", "playerID", tostring(player))
				end
			end
		end
	end


	function gadget:UnitSeismicPing(x, y, z, strength, allyTeam, unitID, unitDefID)
		local event = "StealthyUnitsDetected"
		local players = Spring.GetPlayerList()
		local unitAllyTeam = Spring.GetUnitAllyTeam(unitID)
		local _, _, spec, _, playerAllyTeam
		for ct, playerID in pairs (players) do
			if tostring(playerID) then
				_, _, spec, _, playerAllyTeam = spGetPlayerInfo(playerID, false)
				if not spec and playerAllyTeam == allyTeam and unitAllyTeam ~= playerAllyTeam then
					GG["notifications"].queueNotification(event, "playerID", tostring(playerID))
				end
			end
		end
	end

else

	local enableLastcomNotif = (Spring.GetModOptions().deathmode == 'com')

	local isCommander = {}
	local isRadar = {}
	local isMex = {}
	local isLrpc = {}
	local isBuilding = {}
	local hasWeapons = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		-- not critter/raptor/object
		if not string.find(unitDef.name, 'critter') and not string.find(unitDef.name, 'raptor') and (not unitDef.modCategories or not unitDef.modCategories.object) then
			if unitDef.customParams.iscommander or unitDef.customParams.isscavcommander then
				isCommander[unitDefID] = true
			end
			if string.find(unitDef.name,'corint') or string.find(unitDef.name,'armbrtha') or string.find(unitDef.name,'corbuzz') or string.find(unitDef.name,'armvulc') or string.find(unitDef.name,'legstarfall') then
				isLrpc[unitDefID] = true
			end
			if unitDef.isBuilding and unitDef.radarDistance > 1900 then
				isRadar[unitDefID] = unitDef.radarDistance
			end
			if unitDef.extractsMetal > 0 then
				isMex[unitDefID] = unitDef.extractsMetal
			end
			if unitDef.weapons and #unitDef.weapons > 0 then
				hasWeapons[unitDefID] = true
			end
			isBuilding[unitDefID] = unitDef.isBuilding or unitDef.isFactory
		end
	end

	local isSpec = Spring.GetSpectatingState()
	local myTeamID = Spring.GetMyTeamID()
	local myPlayerID = Spring.GetMyPlayerID()
	local myAllyTeamID = Spring.GetMyAllyTeamID()
	function gadget:PlayerChanged(playerID)
		isSpec = Spring.GetSpectatingState()
		myTeamID = Spring.GetMyTeamID()
		myPlayerID = Spring.GetMyPlayerID()
		myAllyTeamID = Spring.GetMyAllyTeamID()
	end

	local numTeams = 0
	local playingAsHorde = false
	local myAllyTeamList = Spring.GetTeamList(myAllyTeamID)
	for _, teamID in ipairs(myAllyTeamList) do
		numTeams = numTeams + 1
		if select(4,Spring.GetTeamInfo(teamID,false)) then	-- is AI?
			local luaAI = Spring.GetTeamLuaAI(teamID)
			if luaAI and luaAI ~= "" then
				if string.find(luaAI, 'Scavengers') or string.find(luaAI, 'Raptors') then
					playingAsHorde = true
				end
			end
		end
	end

	local commanderLastDamaged = {}

	function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		if unitTeam == myTeamID and isLrpc[attackerDefID] and attackerTeam and GetAllyTeamID(attackerTeam) ~= myAllyTeamID then
			GG["notifications"].queueNotification('LrpcTargetUnits', "playerID", tostring(myPlayerID))
		end
		if isCommander[unitDefID] then
			commanderLastDamaged[unitID] = Spring.GetGameFrame()
		end
		if unitTeam == myTeamID and attackerTeam and GetAllyTeamID(attackerTeam) ~= myAllyTeamID then
			if isCommander[unitDefID] then
				local health, maxhealth = Spring.GetUnitHealth(unitID)
				local healthPercent = health/maxhealth
				if healthPercent < 0.2 then
					GG["notifications"].queueNotification('ComHeavyDamage', "playerID", tostring(myPlayerID))
				else
					GG["notifications"].queueNotification('CommanderUnderAttack', "playerID", tostring(myPlayerID))
				end
			elseif isBuilding[unitDefID] == true and (not isMex[unitDefID]) and (not hasWeapons[unitDefID]) and (not isRadar[unitDefID]) then
				GG["notifications"].queueNotification('BaseUnderAttack', "playerID", tostring(myPlayerID))
			elseif isBuilding[unitDefID] == false then
				GG["notifications"].queueNotification('UnitsUnderAttack', "playerID", tostring(myPlayerID))
			end
		end
	end

	function gadget:GameFrame(frame)

	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
		--local unitInView = Spring.IsUnitInView(unitID)

		-- if own and not killed by yourself
		if not isSpec and unitTeam == myTeamID and attackerTeam and attackerTeam ~= unitTeam then -- and not unitInView
			if isRadar[unitDefID] then
				local event = isRadar[unitDefID] > 2800 and 'AdvRadarLost' or 'RadarLost'
				GG["notifications"].queueNotification(event, "playerID", tostring(myPlayerID))
				return
			end
			if isMex[unitDefID] then
				GG["notifications"].queueNotification("MetalExtractorLost", "playerID", tostring(myPlayerID))
				return
			end
			if not isCommander[unitDefID] then
				GG["notifications"].queueNotification("UnitLost", "playerID", tostring(myPlayerID))
				return
			end
		end

		if isCommander[unitDefID] and not select(3, Spring.GetTeamInfo(unitTeam)) then
			local myComCount = 0
			local allyComCount = 0
			local myAllyTeamList = Spring.GetTeamList(myAllyTeamID)
			for _, teamID in ipairs(myAllyTeamList) do
				if unitTeam == teamID then
					allyComCount = allyComCount - 1	-- current com death has not been subtracted from GetTeamUnitDefCount yet, so we do this manually
					if unitTeam == myTeamID then
						myComCount = myComCount - 1
					end
				end
				for unitDefID,_ in pairs(isCommander) do
					local comCount = Spring.GetTeamUnitDefCount(teamID, unitDefID)
					allyComCount = allyComCount + comCount
					if teamID == myTeamID and comCount > 0 then
						myComCount = myComCount + comCount
					end
				end
			end
			if not isSpec then
				if numTeams > 1 and not playingAsHorde then
					local players =  PlayersInAllyTeamID(GetAllyTeamID(Spring.GetUnitTeam(unitID)))
					for ct, player in pairs (players) do
						if tostring(player) then
							--if not unitInView then
								if Spring.GetUnitRulesParam(unitID, "unit_evolved") then

								elseif not attackerTeam and select(6, Spring.GetTeamInfo(unitTeam, false)) == myAllyTeamID and (not commanderLastDamaged[unitID] or commanderLastDamaged[unitID]+150 < Spring.GetGameFrame()) then
									GG["notifications"].queueNotification("FriendlyCommanderSelfD", "playerID", tostring(player))
								else
									GG["notifications"].queueNotification("FriendlyCommanderDied", "playerID", tostring(player))
								end
							--end
							if enableLastcomNotif and allyComCount == 1 then
								if myComCount == 1 then
									GG["notifications"].queueNotification("YouHaveLastCommander", "playerID", tostring(player))
								else
									GG["notifications"].queueNotification("TeamDownLastCommander", "playerID", tostring(player))
								end
							end
						end
					end
				end
				--if not unitInView then
					local players =  AllButAllyTeamID(GetAllyTeamID(Spring.GetUnitTeam(unitID)))
					for ct, player in pairs (players) do
						if tostring(player) and not Spring.GetUnitRulesParam(unitID, "unit_evolved") then
							GG["notifications"].queueNotification("EnemyCommanderDied", "playerID", tostring(player))
						end
					end
				--end
			else
				local players = PlayersInAllyTeamID(GetAllyTeamID(Spring.GetUnitTeam(unitID)))
				for ct, player in pairs (players) do
					if tostring(player) then
						if Spring.GetUnitRulesParam(unitID, "unit_evolved") then

						elseif not attackerTeam and (not commanderLastDamaged[unitID] or commanderLastDamaged[unitID]+150 < Spring.GetGameFrame()) then
							GG["notifications"].queueNotification("NeutralCommanderSelfD", "playerID", tostring(player), true)
						else
							GG["notifications"].queueNotification("NeutralCommanderDied", "playerID", tostring(player), true)
						end
					end
				end
				local players = AllButAllyTeamID(GetAllyTeamID(Spring.GetUnitTeam(unitID)))
				for ct, player in pairs (players) do
					if tostring(player) then
						if Spring.GetUnitRulesParam(unitID, "unit_evolved") then

						elseif not attackerTeam and (not commanderLastDamaged[unitID] or commanderLastDamaged[unitID]+150 < Spring.GetGameFrame()) then
							GG["notifications"].queueNotification("NeutralCommanderSelfD", "playerID", tostring(player), true)
						else
							GG["notifications"].queueNotification("NeutralCommanderDied", "playerID", tostring(player), true)
						end
					end
				end
			end
			commanderLastDamaged[unitID] = nil
		end
	end
end
