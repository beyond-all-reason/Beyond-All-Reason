local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "No Share Self-D",
		desc      = "Prevents self-destruction when a unit changes hands or a player leaves",
		author    = "quantum, Bluestone",
		date      = "July 13, 2008",
		license   = "GNU GPL, v2 or later",
		layer     = -99999,
		enabled   = true
	}
end


if not gadgetHandler:IsSyncedCode() then
	return
end

local monitorPlayers = {}
local spGetPlayerInfo = Spring.GetPlayerInfo

function gadget:Initialize()
	-- Register validator with BARTransfer system
	if GG.BARTransfer then
		GG.BARTransfer.RegisterValidator("PreventShareSelfD", function(unitID, unitDefID, oldTeam, newTeam, reason)
			if not unitID or type(unitID) ~= "number" then
				return true
			end
			
			local success, cmdQueue = pcall(Spring.GetUnitCommands, unitID)
			if not success or not cmdQueue or #cmdQueue == 0 then
				return true
			end
			if Spring.GetUnitSelfDTime(unitID) > 0 then
				Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, 0)
			end
			return true
		end)
	end
end

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

function gadget:Initialize()
	local players = Spring.GetPlayerList()
	for _, playerID in pairs(players) do
		local _,active,spec,teamID = spGetPlayerInfo(playerID,false)
		local leaderPlayerID, isDead, isAiTeam = Spring.GetTeamInfo(teamID)
		if isDead == 0 and not isAiTeam then
			--_, active, spec = spGetPlayerInfo(leaderPlayerID, false)
			if active and not spec then
				monitorPlayers[playerID] = true
			end
		end
	end
end

function gadget:GameFrame(gameFrame)
	local active,spec,teamID
	for playerID, prevActive in pairs(monitorPlayers) do
		_,active,spec,teamID = spGetPlayerInfo(playerID,false)
		if spec then
			removeSelfdOrders(teamID)
			monitorPlayers[playerID] = nil
		elseif active ~= prevActive then
			if not active then
				removeSelfdOrders(teamID)
			end
			monitorPlayers[playerID] = active	-- dont nil cause player could reconnect
		end
	end
end
