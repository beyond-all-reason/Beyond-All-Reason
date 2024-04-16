function gadget:GetInfo()
	return {
		name      = "No Share Self-D",
		desc      = "Prevents self-destruction when a unit changes hands or a player leaves",
		author    = "quantum, Bluestone",
		date      = "July 13, 2008",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end


if not gadgetHandler:IsSyncedCode() then

	function gadget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
		-- remove self d commands on shared units
		if Spring.GetUnitSelfDTime(unitID) > 0 then
			Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, 0)
		end
	end

	function gadget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
		-- remove self d commands on shared units
		if Spring.GetUnitSelfDTime(unitID) > 0 then
			Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, 0)
		end
	end

else

	local function removeSelfdOrders(teamID)
		-- check team is empty
		--local team = Spring.GetPlayerList(teamID)
		--if team then
		--	for _,pID in pairs(team) do
		--		local _,active,spec = Spring.GetPlayerInfo(pID,false)
		--		if active and not spec then
		--			return
		--		end
		--	end
		--end

		-- cancel any self d orders
		local units = Spring.GetTeamUnits(teamID)
		for i=1,#units do
			local unitID = units[i]
			if Spring.GetUnitSelfDTime(unitID) > 0 then
				Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, 0)
			end
		end
	end

	local monitorPlayers = {}
	function gadget:Initialize()
		local players = Spring.GetPlayerList()
		for _, playerID in pairs(players) do
			local _,active,spec,teamID = Spring.GetPlayerInfo(playerID,false)
			local leaderPlayerID, isDead, isAiTeam = Spring.GetTeamInfo(teamID)
			if isDead == 0 and not isAiTeam then
				_, active, spec = Spring.GetPlayerInfo(leaderPlayerID, false)
				if active and not spec then
					monitorPlayers[playerID] = true
				end
			end
		end
	end

	function gadget:GameFrame(gameFrame)
		for playerID, prevActive in pairs(monitorPlayers) do
			local _,active,spec,teamID = Spring.GetPlayerInfo(playerID,false)
			if spec then
				removeSelfdOrders(teamID)
				monitorPlayers[playerID] = nil
			elseif not active and prevActive then
				removeSelfdOrders(teamID)
				monitorPlayers[playerID] = active	-- dont nil cause player could reconnect
			end
		end
	end

end
