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

local function TakeCommand(cmd, line, words, playerID)
	local _, _, _, teamID = Spring.GetPlayerInfo(playerID)
	local allyTeamID = Spring.GetTeamAllyTeamID(teamID)
	
	local teamList = Spring.GetTeamList(allyTeamID)
	local playerList = Spring.GetPlayerList()
	
	for _, otherTeamID in ipairs(teamList) do
		if otherTeamID ~= teamID then
			-- Check if team has any active players
			local hasActivePlayer = false
			for _, pID in ipairs(playerList) do
				local _, active, spectator, pTeamID = Spring.GetPlayerInfo(pID)
				if active and not spectator and pTeamID == otherTeamID then
					hasActivePlayer = true
					break
				end
			end
			
			if not hasActivePlayer then
				-- Transfer everything
				-- 1. Units
				local units = Spring.GetTeamUnits(otherTeamID)
				for _, unitID in ipairs(units) do
					Spring.TransferUnit(unitID, teamID, true)
				end
				
				-- 2. Resources
				local metal = GG.GetTeamResources(otherTeamID, "metal")
				local energy = GG.GetTeamResources(otherTeamID, "energy")

				if metal > 0 then
					GG.ShareTeamResource(otherTeamID, teamID, "metal", metal)
				end
				if energy > 0 then
					GG.ShareTeamResource(otherTeamID, teamID, "energy", energy)
				end
			end
		end
	end
	return true
end

function gadget:Initialize()
	gadgetHandler:AddChatAction("take", TakeCommand, "Takes control of units from empty allied teams")
end

function gadget:Shutdown()
	gadgetHandler:RemoveChatAction("take")
end
