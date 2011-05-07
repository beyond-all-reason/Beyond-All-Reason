
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
	
    local teamList = Spring.GetTeamList()
    for i = 1, #teamList do
        local teamID = teamList[i]
        Spring.SetTeamResource(teamID, 'ms', startMetal)
        Spring.SetTeamResource(teamID, 'm' , startMetal)
        Spring.SetTeamResource(teamID, 'es', startEnergy)
        Spring.SetTeamResource(teamID, 'e' , startEnergy)
    end
end

function gadget:TeamDied(teamID)
	Spring.SetTeamShareLevel(teamID, 'metal', 0)
	Spring.SetTeamShareLevel(teamID, 'energy', 0)
end
