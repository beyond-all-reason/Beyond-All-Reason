local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "game_no_share_to_enemy",
		desc = "Disallows sharing to enemies",
		author = "TheFatController",
		date = "19 Jan 2008",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if not gadgetHandler:IsSyncedCode() then
	return
end

local AreTeamsAllied = SpringShared.AreTeamsAllied
local IsCheatingEnabled = SpringShared.IsCheatingEnabled

local isNonPlayerTeam = { [SpringShared.GetGaiaTeamID()] = true }
local teams = SpringShared.GetTeamList()
for i = 1, #teams do
	local _, _, _, isAiTeam = SpringShared.GetTeamInfo(teams[i], false)
	local isLuaAI = (SpringShared.GetTeamLuaAI(teams[i]) ~= nil)
	if isAiTeam or isLuaAI then
		isNonPlayerTeam[teams[i]] = true
	end
end

function gadget:AllowResourceTransfer(oldTeam, newTeam, type, amount)
	if isNonPlayerTeam[oldTeam] or AreTeamsAllied(newTeam, oldTeam) or IsCheatingEnabled() then
		return true
	end

	return false
end

function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
	if isNonPlayerTeam[oldTeam] or AreTeamsAllied(newTeam, oldTeam) or capture or IsCheatingEnabled() then
		return true
	end

	return false
end
