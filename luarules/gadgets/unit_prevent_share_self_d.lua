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
    GG.TeamTransfer.RegisterUnitValidator("PreventShareSelfD", function(unitID, unitDefID, oldTeam, newTeam, reason)
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
