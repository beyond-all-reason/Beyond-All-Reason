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

function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
	removeSelfDOrders(unitID)
	return true
end

local function removeSelfDOrders(unitID)
	-- cancel any current self-D orders
	if Spring.GetUnitSelfDTime(unitID) > 0 then
		Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, 0)
	end

	-- for queued self-D orders, remove them from queue
	local selfdTags = {}
	for index = 1, Spring.GetUnitCommandCount(unitID) do
		local cmd, _, tag = Spring.GetUnitCurrentCommand(unitID, index)
		if cmd == CMD.SELFD then
			selfdTags[#selfdTags + 1] = tag
		end
	end
	if #selfdTags > 0 then
		Spring.GiveOrderToUnit(unitID, CMD.REMOVE, selfdTags, 0)
	end
end

local function removeTeamSelfDOrders(teamID)
	local units = Spring.GetTeamUnits(teamID)
	for i = 1, #units do
		removeSelfDOrders(units[i])
	end
end

function gadget:Initialize()
	local players = Spring.GetPlayerList()
	for _, playerID in pairs(players) do
		local _,active,spec,teamID = spGetPlayerInfo(playerID,false)
		local leaderPlayerID, isDead, isAiTeam = Spring.GetTeamInfo(teamID, false)
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
			removeTeamSelfDOrders(teamID)
			monitorPlayers[playerID] = nil
		elseif active ~= prevActive then
			if not active then
				removeTeamSelfDOrders(teamID)
			end
			monitorPlayers[playerID] = active	-- dont nil cause player could reconnect
		end
	end
end
