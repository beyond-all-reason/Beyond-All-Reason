function gadget:GetInfo()
	return {
		name = "ffa",
		desc = "No owner code for FFA games. Removes abandoned teams",
		author = "TheFatController",
		date = "19 Jan 2008",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true    --	loaded by default?
	}
end

if not Spring.GetModOptions().ffa_mode then
	return false
end

if gadgetHandler:IsSyncedCode() then

	local earlyDropLimit = Game.gameSpeed * 60 * 2 -- in frames
	local earlyDropGrace = Game.gameSpeed * 60 * 1 -- in frames
	local lateDropGrace = Game.gameSpeed * 60 * 3 -- in frames

	local leaveWreckage = Spring.GetModOptions().ffa_wreckage or false
	local leaveWreckageFromFrame = Game.gameSpeed * 60 * 3

	local GetPlayerInfo = Spring.GetPlayerInfo
	local GetPlayerList = Spring.GetPlayerList
	local GetTeamList = Spring.GetTeamList
	local GetAIInfo = Spring.GetAIInfo
	local GetTeamLuaAI = Spring.GetTeamLuaAI
	local deadTeam = {}
	local droppedTeam = {}
	local teamsWithUnitsToKill = {}
	local gaiaTeamID = Spring.GetGaiaTeamID()

	function gadget:Initialize()
		if Spring.GetGameFrame() >= leaveWreckageFromFrame then
			GG.wipeoutWithWreckage = leaveWreckage
		end
	end

	local function GetTeamIsTakeable(teamID)
		local players = GetPlayerList(teamID)
		local allResigned = true
		local noneControlling = true

		-- team is handled by lua scripts
		if teamID == gaiaTeamID or GetTeamLuaAI(teamID) ~= "" then
			allResigned, noneControlling = false, false
		end

		for _, playerID in pairs(players) do
			local name, active, spec = GetPlayerInfo(playerID, false)
			allResigned = allResigned and spec
			noneControlling = noneControlling and (not active or spec)
		end

		-- team is handled by skirmish AI, make sure the hosting player is present
		if GetAIInfo(teamID) then
			allResigned = false
			local hostingPlayerID = select(3, GetAIInfo(teamID))
			noneControlling = noneControlling and not select(2, GetPlayerInfo(hostingPlayerID, false))
		end
		return noneControlling, allResigned
	end

	function gadget:TeamDied(teamID)
		-- make sure units are killed properly
		-- we cannot kill units here directly or it'd complain about recursion
		teamsWithUnitsToKill[teamID] = true
	end

	local function destroyTeam(teamID, gameFrame)
		-- old code also used Spring.GetUnitTransporter to exclude destroying transported units
		Spring.KillTeam(teamID)
		deadTeam[teamID] = true
		SendToUnsynced("TeamDestroyed", teamID)
	end

	function gadget:GameFrame(gameFrame)
		if gameFrame == leaveWreckageFromFrame then
			GG.wipeoutWithWreckage = leaveWreckage
		end

		for teamID in pairs(teamsWithUnitsToKill) do
			if gameFrame < earlyDropGrace then
				Spring.Echo('mo_ffa: TeamDied teamID: '..teamID)
			end
			destroyTeam(teamID, gameFrame)
			teamsWithUnitsToKill[teamID] = nil
		end
		for _, teamID in pairs(GetTeamList()) do
			if not deadTeam[teamID] then
				local noneControlling, allResigned = GetTeamIsTakeable(teamID)
				if noneControlling then
					if allResigned then
						if gameFrame < earlyDropGrace then
							Spring.Echo('mo_ffa: destroy resigned teamID: '..teamID)
						end
						destroyTeam(teamID, gameFrame) -- destroy the team immediately if all players in it resigned
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
		for teamID, frame in pairs(droppedTeam) do
			if gameFrame - frame > (frame < earlyDropLimit and earlyDropGrace or lateDropGrace) then
				if gameFrame < leaveWreckageFromFrame then
					Spring.Echo('mo_ffa: remove dropped teamID: '..teamID..', leaving no wreckage')
					local teamUnits = Spring.GetTeamUnits(teamID)
					for i=1, #teamUnits do
						Spring.DestroyUnit(teamUnits[i], false, true)	-- reclaim, dont want to leave FFA comwreck for idling starts
					end
				end
				destroyTeam(teamID, frame)
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

else  -- UNSYNCED

	local function teamDestroyed(_, teamID)
		if Script.LuaUI('GadgetMessageProxy') then
			local message = Script.LuaUI.GadgetMessageProxy('ui.ffaNoOwner.destroyed', { team = teamID })
			Spring.SendMessage(message)
		end
	end

	local function playerWarned(_, teamID, gracePeriod)
		if Script.LuaUI('GadgetMessageProxy') then
			local message = Script.LuaUI.GadgetMessageProxy('ui.ffaNoOwner.disconnected', { team = teamID, gracePeriod = gracePeriod })
			Spring.SendMessage(message)
		end
	end

	local function playerReconnected(_, teamID)
		if Script.LuaUI('GadgetMessageProxy') then
			local message = Script.LuaUI.GadgetMessageProxy('ui.ffaNoOwner.reconnected', { team = teamID })
			Spring.SendMessage(message)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("TeamDestroyed", teamDestroyed)
		gadgetHandler:AddSyncAction("PlayerWarned", playerWarned)
		gadgetHandler:AddSyncAction("PlayerReconnected", playerReconnected)
	end
end
