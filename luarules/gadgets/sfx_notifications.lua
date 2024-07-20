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
	local nukesNames = {
		armsilo_nuclear_missile = true,
		corsilo_crblmssl = true,
		armsilo_scav_nuclear_missile = true,
		corsilo_scav_crblmssl = true,
		raptor_turret_meteor_t4_v1_weapon = true,
		--raptor_allterrain_arty_basic_t4_v1_meteorlauncher = true,
	}
	-- convert weaponname -> weaponDefID
	local nukes = {}
	for name, params in pairs(nukesNames) do
		if WeaponDefNames[name] then
			nukes[WeaponDefNames[name].id] = params
		end
	end
	nukesNames = nil

	function gadget:Initialize()
		for k,v in pairs(nukes) do
			Script.SetWatchProjectile(k, true)
		end
	end

	-- UNITS RECEIVED send to all in team
	function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
		if not _G.transferredUnits or not _G.transferredUnits[unitID] then	-- exclude upgraded units (t2 mex/geo) because allied players could have done this
			local players = Spring.GetPlayerList(newTeam)
			for ct, player in pairs (players) do
				if tostring(player) then
					SendToUnsynced("NotificationEvent", "UnitsReceived", tostring(player))
				end
			end
		end
	end

	-- NUKE LAUNCH send to all but ally team
	function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
		local proDefID = Spring.GetProjectileDefID(proID)
		if nukes[Spring.GetProjectileDefID(proID)] then
			local players = AllButAllyTeamID(GetAllyTeamID(Spring.GetUnitTeam(proOwnerID)))
			for ct, player in pairs (players) do
				if tostring(player) then
					SendToUnsynced("NotificationEvent", "NukeLaunched", tostring(player))
				end
			end
		end
	end

	-- Player left send to all in allyteam
	function gadget:PlayerRemoved(playerID, reason)
		local players = PlayersInAllyTeamID(select(5,spGetPlayerInfo(playerID,false)))
		for ct, player in pairs (players) do
			if tostring(player) then
				SendToUnsynced("NotificationEvent", "PlayerLeft", tostring(player))
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
					SendToUnsynced("NotificationEvent", event, tostring(playerID))
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

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("NotificationEvent", BroadcastEvent)
	end

	function BroadcastEvent(_,event, player)
		if Script.LuaUI("NotificationEvent") and tonumber(player) and ((tonumber(player) == Spring.GetMyPlayerID()) or isSpec) then
			Script.LuaUI.NotificationEvent(event.." "..player)
		end
	end

	function gadget:PlayerAdded(playerID)
		if Spring.GetGameFrame() > 0 and not select(3,spGetPlayerInfo(playerID, false)) then
			BroadcastEvent("NotificationEvent", 'PlayerAdded', tostring(myPlayerID))
		end
	end

	local commanderLastDamaged = {}
	function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		if unitTeam == myTeamID and isLrpc[attackerDefID] and attackerTeam and GetAllyTeamID(attackerTeam) ~= myAllyTeamID then
			BroadcastEvent("NotificationEvent", 'LrpcTargetUnits', tostring(myPlayerID))
		end
		if isCommander[unitDefID] then
			commanderLastDamaged[unitID] = Spring.GetGameFrame()
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
		local unitInView = Spring.IsUnitInView(unitID)

		-- if own and not killed by yourself
		if not isSpec and not unitInView and unitTeam == myTeamID and attackerTeam and attackerTeam ~= unitTeam then
			if isRadar[unitDefID] then
				local event = isRadar[unitDefID] > 2800 and 'AdvRadarLost' or 'RadarLost'
				BroadcastEvent("NotificationEvent", event, tostring(myPlayerID))
				return
			elseif isMex[unitDefID] then
				--local event = isMex[unitDefID] > 0.002 and 'T2MexLost' or 'MexLost'
				local event = 'MexLost'
				BroadcastEvent("NotificationEvent", event, tostring(myPlayerID))
				return
			end
		end

		if isCommander[unitDefID] then
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
			if numTeams > 1 and not playingAsHorde then
				local players =  PlayersInAllyTeamID(GetAllyTeamID(Spring.GetUnitTeam(unitID)))
				for ct, player in pairs (players) do
					if tostring(player) then
						if not unitInView then
							if Spring.GetUnitRulesParam(unitID, "unit_evolved") then

							elseif not attackerTeam and select(6, Spring.GetTeamInfo(unitTeam, false)) == myAllyTeamID and (not commanderLastDamaged[unitID] or commanderLastDamaged[unitID]+150 < Spring.GetGameFrame()) then
								BroadcastEvent("NotificationEvent", "FriendlyCommanderSelfD", tostring(player))
							else
								BroadcastEvent("NotificationEvent", "FriendlyCommanderDied", tostring(player))
							end
						end
						if enableLastcomNotif and allyComCount == 1 then
							if myComCount == 1 then
								BroadcastEvent("NotificationEvent", "YouHaveLastCommander", tostring(player))
							else
								BroadcastEvent("NotificationEvent", "TeamDownLastCommander", tostring(player))
							end
						end
					end
				end
			end
			if not unitInView then
				local players =  AllButAllyTeamID(GetAllyTeamID(Spring.GetUnitTeam(unitID)))
				for ct, player in pairs (players) do
					if tostring(player) and not Spring.GetUnitRulesParam(unitID, "unit_evolved") then
						BroadcastEvent("NotificationEvent", "EnemyCommanderDied", tostring(player))
					end
				end
			end
			commanderLastDamaged[unitID] = nil
		end
	end
end
