function gadget:GetInfo()
	return {
		name = 'Team Resourcing',
		desc = 'Sets up team resources',
		author = 'Niobium',
		date = 'May 2011',
		license = 'GNU GPL, v2 or later',
		layer = 1,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local function setup(addResources)

	if Spring.GetGameFrame() > 0 then
		return
	end

	local modOptions = Spring.GetModOptions() or {}
	local startMetal = tonumber(modOptions.startmetal) or 1000
	local startEnergy = tonumber(modOptions.startenergy) or 1000
	local commanderMetalStorage = 500
	local commanderEnergyStorage = 500

	if GG.coopMode then

		local teamPlayerCounts = {}
		local playerList = Spring.GetPlayerList()
		for i = 1, #playerList do
			local playerID = playerList[i]
			local _, _, isSpec, teamID = Spring.GetPlayerInfo(playerID, false)
			if not isSpec then
				teamPlayerCounts[teamID] = (teamPlayerCounts[teamID] or 0) + 1
			end
		end

		local teamList = Spring.GetTeamList()
		for i = 1, #teamList do
			local teamID = teamList[i]
			local multiplier = teamPlayerCounts[teamID] or 1 -- Gaia has no players
			Spring.SetTeamResource(teamID, 'es', startEnergy * multiplier)
			Spring.SetTeamResource(teamID, 'ms', startMetal * multiplier)
			if addResources then
				Spring.SetTeamResource(teamID, 'm', startMetal * multiplier)
				Spring.SetTeamResource(teamID, 'e', startEnergy * multiplier)
			end
		end
	else
		local teamList = Spring.GetTeamList()
		for i = 1, #teamList do
			local teamID = teamList[i]
			Spring.SetTeamResource(teamID, 'ms', startMetal)
			Spring.SetTeamResource(teamID, 'es', startEnergy)
			if addResources then
				Spring.SetTeamResource(teamID, 'm', startMetal)
				Spring.SetTeamResource(teamID, 'e', startEnergy)
			end
		end
	end
end

function gadget:Initialize()
	setup(true)
end

function gadget:GameStart()
	-- reset because commander added additional storage as well
	setup()
end

function gadget:TeamDied(teamID)
	Spring.SetTeamShareLevel(teamID, 'metal', 0)
	Spring.SetTeamShareLevel(teamID, 'energy', 0)
end


