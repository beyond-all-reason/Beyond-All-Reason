function gadget:GetInfo()
    return {
        name      = "Notifications",
        desc      = "Plays various voice notifications",
        author    = "Doo, Floris",
        date      = "2018",
        license   = "GNU GPL, v2 or later",
        version   = 1,
        layer     = 5,
        enabled   = true  --  loaded by default?
    }
end

local function GetAllyTeamID(teamID)
	return select(6,Spring.GetTeamInfo(teamID,false))
end

local function GetPlayerTeamID(playerID)
	return select(5,Spring.GetPlayerInfo(playerID,false))
end

local function AllPlayers()
	local players = Spring.GetPlayerList()
	for ct, id in pairs(players) do
		if select(3,Spring.GetPlayerInfo(id,false)) then players[ct] = nil end
	end
	return players
end

local function PlayersInAllyTeamID(allyTeamID)
	local players = AllPlayers()
	for ct, id in pairs(players) do
		if select(5,Spring.GetPlayerInfo(id,false)) ~= allyTeamID then players[ct] = nil end
	end
	return players
end

local function AllButAllyTeamID(allyTeamID)
	local players = AllPlayers()
	for ct, id in pairs(players) do
		if select(5,Spring.GetPlayerInfo(id,false)) == allyTeamID then players[ct] = nil end
	end
	return players
end

local function PlayersInTeamID(teamID)
	local players = Spring.GetPlayerList(teamID)
	return players
end

if gadgetHandler:IsSyncedCode() then

	local armnuke = WeaponDefNames["armsilo_nuclear_missile"].id
	local cornuke = WeaponDefNames["corsilo_crblmssl"].id
	local scavArmNuke = WeaponDefNames["armsilo_scav_nuclear_missile"].id
	local scavCorNuke = WeaponDefNames["corsilo_scav_crblmssl"].id
	local gamestarted = (Spring.GetGameFrame() > 0)
	local gameover = false

	function gadget:Initialize()
		Script.SetWatchProjectile(armnuke, true)
		Script.SetWatchProjectile(cornuke, true)
	end

	function gadgetHandler:TeamDied(teamID)

	end

	function gadgetHandler:TeamChanged(teamID)

	end

	function gadgetHandler:PlayerChanged(playerID)

	end

	function gadgetHandler:PlayerAdded(playerID)
		if gamestarted and not gameover then
			local players = AllPlayers()
			for ct, player in pairs (players) do
				if tostring(player) then
					SendToUnsynced("EventBroadcast", "PlayerAdded", tostring(player))
				end
			end
		end
	end

	function gadgetHandler:PlayerRemoved(playerID, reason)

	end

-- UNITS RECEIVED send to all in team
	function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
		local players = PlayersInTeamID(newTeam)
		for ct, player in pairs (players) do
			if tostring(player) then
				SendToUnsynced("EventBroadcast", "UnitsReceived", tostring(player))
			end
		end
	end

-- NUKE LAUNCH send to all but ally team
	function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
		if Spring.GetProjectileDefID(proID) == armnuke or Spring.GetProjectileDefID(proID) == cornuke or Spring.GetProjectileDefID(proID) == scavArmNuke or Spring.GetProjectileDefID(proID) == scavCorNuke then
			local players = AllButAllyTeamID(GetAllyTeamID(Spring.GetUnitTeam(proOwnerID)))
			for ct, player in pairs (players) do
				if tostring(player) then
					SendToUnsynced("EventBroadcast", "NukeLaunched", tostring(player))
				end
			end
		end
	end

-- Game paused send to all
	function gadget:GamePaused()
		local players = AllPlayers()
		for ct, player in pairs (players) do
			if tostring(player) then
				SendToUnsynced("EventBroadcast", "GamePause", tostring(player))
			end
		end
	end

--Game started send to all
	function gadget:GameStart()
		gamestarted = true
		local players = AllPlayers()
		for ct, player in pairs (players) do
			if tostring(player) then
				SendToUnsynced("EventBroadcast", "GameStarted", tostring(player))
			end
		end
	end

	function gadgetHandler:GameOver(winningAllyTeams)
		gameover = true
	end

--Player left send to all in allyteam
	function gadget:PlayerRemoved(playerID, reason)
		local players = PlayersInAllyTeamID(GetPlayerTeamID(playerID))
		for ct, player in pairs (players) do
			if tostring(player) then
				SendToUnsynced("EventBroadcast", "PlayerLeft", tostring(player))
			end
		end
	end


	function gadget:UnitSeismicPing(x, y, z, strength, allyTeam, unitID, unitDefID)
		local event = "IntrusionCountermeasure"
		local players = AllPlayers()
		local unitAllyTeam = Spring.GetUnitAllyTeam(unitID)
		for ct, player in pairs (players) do
			if tostring(player) then
				local playerAllyTeam = select(5,Spring.GetPlayerInfo(player))
				if playerAllyTeam == allyTeam and unitAllyTeam ~= playerAllyTeam then
					SendToUnsynced("EventBroadcast", event, tostring(player))
				end
			end
		end
	end

else

	local enableLastcomNotif = (Spring.GetModOptions().deathmode == 'com' and Spring.GetModOptions().scoremode == 'disabled')

	local isCommander = {}
	local isRadar = {}
	local isMex = {}
	local isLrpc = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		-- not critter/chicken/object
		if not string.find(unitDef.name, 'critter') and not string.find(unitDef.name, 'chicken') and (not unitDef.modCategories or not unitDef.modCategories.object) then
			if unitDef.customParams.iscommander and not string.find(unitDef.name,'_scav') then
				isCommander[unitDefID] = true
			end
			if string.find(unitDef.name,'corint') or string.find(unitDef.name,'armbrtha') or string.find(unitDef.name,'corbuzz') or string.find(unitDef.name,'armvulc') then
				isLrpc[unitDefID] = true
			end
			if unitDef.isBuilding and unitDef.radarRadius > 1900 then
				isRadar[unitDefID] = unitDef.radarRadius
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
				if string.find(luaAI, 'Scavengers') or string.find(luaAI, 'Chickens') then
					playingAsHorde = true
				end
			end
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("EventBroadcast", BroadcastEvent)
	end

	function BroadcastEvent(_,event, player)
		if Script.LuaUI("EventBroadcast") and tonumber(player) and ((tonumber(player) == Spring.GetMyPlayerID()) or isSpec) then
			Script.LuaUI.EventBroadcast("SoundEvents "..event.." "..player)
		end
	end

	function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		if unitTeam == myTeamID and isLrpc[attackerDefID] and attackerTeam and GetAllyTeamID(attackerTeam) ~= myAllyTeamID then
			BroadcastEvent("EventBroadcast", 'LrpcTargetUnits', tostring(myPlayerID))
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
		local unitInView = Spring.IsUnitInView(unitID)

		-- if own and not killed by yourself
		if not isSpec and not unitInView and unitTeam == myTeamID and attackerTeam and attackerTeam ~= unitTeam then
			if isRadar[unitDefID] then
				local event = isRadar[unitDefID] > 2800 and 'AdvRadarLost' or 'RadarLost'
				BroadcastEvent("EventBroadcast", event, tostring(myPlayerID))
				return
			elseif isMex[unitDefID] then
				--local event = isMex[unitDefID] > 0.002 and 'T2MexLost' or 'MexLost'
				local event = 'MexLost'
				BroadcastEvent("EventBroadcast", event, tostring(myPlayerID))
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
							BroadcastEvent("EventBroadcast", "FriendlyCommanderDied", tostring(player))
						end
						if enableLastcomNotif and allyComCount == 1 then
							if myComCount == 1 then
								BroadcastEvent("EventBroadcast", "YouHaveLastCommander", tostring(player))
							else
								BroadcastEvent("EventBroadcast", "TeamDownLastCommander", tostring(player))
							end
						end
					end
				end
			end
			if not unitInView then
				local players =  AllButAllyTeamID(GetAllyTeamID(Spring.GetUnitTeam(unitID)))
				for ct, player in pairs (players) do
					if tostring(player) then
						BroadcastEvent("EventBroadcast", "EnemyCommanderDied", tostring(player))
					end
				end
			end
		end
	end
end
