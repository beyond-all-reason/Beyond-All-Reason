function gadget:GetInfo()
	return {
		name      = "Take Command",
		desc      = "Implements /take command to transfer units/resources from empty allied teams",
		author    = "Antigravity",
		date      = "2024",
		license   = "GPL-v2",
		layer     = 0,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local TAKE_MSG = "take_cmd"

local function ExecuteTake(playerID)
	local _, _, spec, teamID = Spring.GetPlayerInfo(playerID)
	if spec then return end
	
	local allyTeamID = Spring.GetTeamAllyTeamID(teamID)
	local teamList = Spring.GetTeamList(allyTeamID)
	local playerList = Spring.GetPlayerList()

	Spring.Log("TakeCommand", LOG.ERROR, "[LUA] Taking control of units from empty allied teams")

	for _, otherTeamID in ipairs(teamList) do
		if otherTeamID ~= teamID then
			local hasActivePlayer = false
			for _, pID in ipairs(playerList) do
				local _, active, spectator, pTeamID = Spring.GetPlayerInfo(pID)
				if active and not spectator and pTeamID == otherTeamID then
					hasActivePlayer = true
					break
				end
			end
			
			if not hasActivePlayer then
				local units = Spring.GetTeamUnits(otherTeamID)
				for _, unitID in ipairs(units) do
					Spring.TransferUnit(unitID, teamID, true)
				end
				
				local metal = GG.GetTeamResources and GG.GetTeamResources(otherTeamID, "metal")
				local energy = GG.GetTeamResources and GG.GetTeamResources(otherTeamID, "energy")

				if metal and metal > 0 and GG.ShareTeamResource then
					GG.ShareTeamResource(otherTeamID, teamID, "metal", metal)
				end
				if energy and energy > 0 and GG.ShareTeamResource then
					GG.ShareTeamResource(otherTeamID, teamID, "energy", energy)
				end
			end
		end
	end
end

function gadget:RecvLuaMsg(msg, playerID)
	if msg == TAKE_MSG then
		ExecuteTake(playerID)
		return true
	end
end
