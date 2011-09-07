
function gadget:GetInfo()
	return {
		name      = 'Team Resourcing',
		desc      = 'Sets up team resources',
		author    = 'Niobium',
		date      = 'May 2011',
		license   = 'GNU GPL, v2 or later',
		layer     = 0,
		enabled   = true
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
function gadget:Initialize()
	
	local modOptions = Spring.GetModOptions() or {}
	local startMetal  = tonumber(modOptions.startmetal)  or 1000
	local startEnergy = tonumber(modOptions.startenergy) or 1000
	local teamResources = true 

	if ((modOptions.mo_storageowner) and (modOptions.mo_storageowner == "com")) then
    teamResources = false
	end
	
    if GG.coopMode then
        
        local teamPlayerCounts = {}
        local playerList = Spring.GetPlayerList()
        for i = 1, #playerList do
            local playerID = playerList[i]
            local _, _, isSpec, teamID = Spring.GetPlayerInfo(playerID)
            if not isSpec then
                teamPlayerCounts[teamID] = (teamPlayerCounts[teamID] or 0) + 1
            end
        end
        
        local teamList = Spring.GetTeamList()
        for i = 1, #teamList do
            local teamID = teamList[i]
            local multiplier = teamPlayerCounts[teamID] or 1 -- Gaia has no players
            if (teamResources) then
              Spring.SetTeamResource(teamID, 'es', startEnergy * multiplier)
              Spring.SetTeamResource(teamID, 'ms', startMetal  * multiplier)
            else
              Spring.SetTeamResource(teamID, 'es', 20 * multiplier)
              Spring.SetTeamResource(teamID, 'ms', 20 * multiplier)
            end
            Spring.SetTeamResource(teamID, 'm' , startMetal  * multiplier)
            Spring.SetTeamResource(teamID, 'e' , startEnergy * multiplier)
        end
    else
        local teamList = Spring.GetTeamList()
        for i = 1, #teamList do
            local teamID = teamList[i]
            if (teamResources) then
              Spring.SetTeamResource(teamID, 'ms', startMetal)
              Spring.SetTeamResource(teamID, 'es', startEnergy)
            else
              Spring.SetTeamResource(teamID, 'es', 20)
              Spring.SetTeamResource(teamID, 'ms', 20)
            end
            Spring.SetTeamResource(teamID, 'm' , startMetal)
            Spring.SetTeamResource(teamID, 'e' , startEnergy)
        end
    end
end

function gadget:TeamDied(teamID)
	Spring.SetTeamShareLevel(teamID, 'metal', 0)
	Spring.SetTeamShareLevel(teamID, 'energy', 0)
end


