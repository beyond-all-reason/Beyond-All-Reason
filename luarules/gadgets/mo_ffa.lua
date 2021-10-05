function gadget:GetInfo()
	return {
		name = "ffa",
		desc = "No owner code for FFA games. Removes abandoned teams",
		author = "TheFatController",
		date = "19 Jan 2008",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true	--	loaded by default?
	}
end

if not Spring.GetModOptions().ffa_mode then
	return false
end

if gadgetHandler:IsSyncedCode() then

	-- teams dying before this mark don't leave wrecks
	local noWrecksLimit = Game.gameSpeed * 60 * 5 -- in frames
	local earlyDropLimit = Game.gameSpeed * 60 * 2 -- in frames
	local earlyDropGrace = Game.gameSpeed * 60 * 1 -- in frames
	local lateDropGrace = Game.gameSpeed * 60 * 3 -- in frames

	local GetPlayerInfo = Spring.GetPlayerInfo
	local GetPlayerList = Spring.GetPlayerList
	local GetTeamList = Spring.GetTeamList
	local GetTeamUnits = Spring.GetTeamUnits
	local DestroyUnit = Spring.DestroyUnit
	local GetUnitTransporter = Spring.GetUnitTransporter
	local GetAIInfo = Spring.GetAIInfo
	local GetTeamLuaAI = Spring.GetTeamLuaAI
	local deadTeam = {}
	local droppedTeam = {}
	local teamsWithUnitsToKill = {}
	local gaiaTeamID = Spring.GetGaiaTeamID()

	local function GetTeamIsTakeable(teamID)
		local players = GetPlayerList(teamID)
		local allResigned = true
		local noneControlling = true

		-- team is handled by lua scripts
		if teamID == gaiaTeamID or GetTeamLuaAI(teamID) ~= "" then
			allResigned, noneControlling = false, false
		end

		for _, playerID in pairs(players) do
			local name, active, spec = GetPlayerInfo(playerID,false)
			allResigned = allResigned and spec
			noneControlling = noneControlling and ( not active or spec )
		end

		-- team is handled by skirmish AI, make sure the hosting player is present
		if GetAIInfo(teamID) then
			allResigned = false
			local hostingPlayerID = select(3,GetAIInfo(teamID))
			noneControlling = noneControlling and not select(2,GetPlayerInfo(hostingPlayerID,false))
		end
		return noneControlling, allResigned
	end

	function gadget:TeamDied(teamID)
		-- make sure units are killed properly
		-- we cannot kill units here directly or it'd complain about recursion
		teamsWithUnitsToKill[teamID] = true
	end

	local function destroyTeam(teamID,dropTime)
		local teamUnits = GetTeamUnits(teamID)
		local nowrecks = dropTime < noWrecksLimit
		for i=1, #teamUnits do
			local unitID = teamUnits[i]
			if not GetUnitTransporter(unitID) then
				if nowrecks then
					DestroyUnit(unitID, false, true)
				else
					DestroyUnit(unitID)
				end
			end
		end
		if nowrecks then
			SendToUnsynced("TeamRemoved", teamID)
		else
			SendToUnsynced("TeamDestroyed", teamID)
		end
		deadTeam[teamID] = true
	end

	function gadget:GameFrame(gameFrame)
		for teamID in pairs(teamsWithUnitsToKill) do
			destroyTeam(teamID,gameFrame)
			teamsWithUnitsToKill[teamID] = nil
		end
		for _, teamID in pairs(GetTeamList()) do
			if not deadTeam[teamID] then
				local noneControlling, allResigned = GetTeamIsTakeable(teamID)
				if noneControlling then
					if allResigned then
						destroyTeam(teamID,gameFrame) -- destroy the team immediately if all players in it resigned
					elseif not droppedTeam[teamID] then
						local gracePeriod = gameFrame < earlyDropLimit and earlyDropGrace or lateDropGrace
						local minutesGrace = math.floor(gracePeriod / (Game.gameSpeed * 60))
						SendToUnsynced("PlayerWarned", teamID, minutesGrace)
						droppedTeam[teamID] = gameFrame
					end
				elseif droppedTeam[teamID] then
					SendToUnsynced("PlayerReconnected", teamID)
					droppedTeam[teamID] = nil
				end
			end
		end
		for teamID,time in pairs(droppedTeam) do
			if gameFrame - time > (time < earlyDropLimit and earlyDropGrace or lateDropGrace) then
				destroyTeam(teamID, time)
				droppedTeam[teamID] = nil
			end
		end
	end

	function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
		return not deadTeam[newTeam]
	end

	function gadget:GameOver()
		gadgetHandler:RemoveGadget(self)
	end

else	-- UNSYNCED

	local function teamRemoved(_, teamID)
		Spring.SendMessage(Spring.I18N('ui.ffaNoOwner.removed', { team = teamID }))
	end

	local function teamDestroyed(_, teamID)
		Spring.SendMessage(Spring.I18N('ui.ffaNoOwner.destroyed', { team = teamID }))
	end

	local function playerWarned(_, teamID, gracePeriod)
		Spring.SendMessage(Spring.I18N('ui.ffaNoOwner.disconnected', { team = teamID, gracePeriod = gracePeriod }))
	end

	local function playerReconnected(_, teamID)
		Spring.SendMessage(Spring.I18N('ui.ffaNoOwner.reconnected', { team = teamID }))
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("TeamRemoved", teamRemoved)
		gadgetHandler:AddSyncAction("TeamDestroyed", teamDestroyed)
		gadgetHandler:AddSyncAction("PlayerWarned", playerWarned)
		gadgetHandler:AddSyncAction("PlayerReconnected", playerReconnected)
	end
end
