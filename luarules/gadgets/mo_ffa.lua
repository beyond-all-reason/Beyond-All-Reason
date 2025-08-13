local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "ffa",
		desc = "No owner code for FFA games. Removes abandoned teams",
		author = "TheFatController",
		date = "19 Jan 2008",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not Spring.Utilities.Gametype.IsFFA() then
	return false
end

if gadgetHandler:IsSyncedCode() then

	local earlyDropLimit = Game.gameSpeed * 60 * 2 -- after this gameframe: lateDropGrace is used instead of earlyDropGrace
	local earlyDropGrace = Game.gameSpeed * 60 * 1 -- in frames
	local lateDropGrace = Game.gameSpeed * 60 * 2 -- in frames

	local isTeamFFA = Spring.Utilities.Gametype.IsTeams()
	if isTeamFFA then
		lateDropGrace = Game.gameSpeed * 8
	end

	local leaveWreckage = Spring.GetModOptions().ffa_wreckage or false
	local leaveWreckageFromFrame = Game.gameSpeed * 60 * 3

	local GetPlayerInfo = Spring.GetPlayerInfo
	local GetPlayerList = Spring.GetPlayerList
	local GetAIInfo = Spring.GetAIInfo
	local GetTeamLuaAI = Spring.GetTeamLuaAI
	local deadTeam = {}
	local droppedTeam = {}
	local teamsWithUnitsToKill = {}
	local gaiaTeamID = Spring.GetGaiaTeamID()
	local teamList = Spring.GetTeamList()
	local teamInfo = {}

	function gadget:Initialize()
		if Spring.GetGameFrame() >= leaveWreckageFromFrame then
			GG.wipeoutWithWreckage = leaveWreckage
		end
		
        GG.TeamTransfer.RegisterUnitValidator("FFADeadTeamBlacklist", function(unitID, unitDefID, oldTeam, newTeam, reason)
            local isSharing = (reason == GG.TeamTransfer.REASON.GIVEN or reason == GG.TeamTransfer.REASON.IDLE_PLAYER_TAKEOVER or reason == GG.TeamTransfer.REASON.TAKEN or reason == GG.TeamTransfer.REASON.SOLD)
				if oldTeam == newTeam or not isSharing then
					return true
				end
				return not deadTeam[newTeam]
			end)
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
