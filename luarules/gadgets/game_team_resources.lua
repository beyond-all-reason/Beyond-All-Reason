local gadget = gadget ---@type Gadget

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

local minStorageMetal = 1000
local minStorageEnergy = 1000
local mathMax = math.max


local function setup(addResources)

	local startMetal = Spring.GetModOptions().startmetal
	local startEnergy = Spring.GetModOptions().startenergy
	local startMetalStorage = Spring.GetModOptions().startmetalstorage
	local startEnergyStorage = Spring.GetModOptions().startenergystorage
	local commanderMinMetal, commanderMinEnergy = 0, 0

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
			
			-- Get the player's start unit to make sure staring storage is no less than its storage
			local com = UnitDefs[Spring.GetTeamRulesParam(teamID, 'startUnit')]
			if com then
				commanderMinMetal = com.metalStorage or 0
				commanderMinEnergy = com.energyStorage or 0
			end

			Spring.SetTeamResource(teamID, 'ms', mathMax(minStorageMetal, startMetalStorage * multiplier, startMetal * multiplier, commanderMinMetal))
			Spring.SetTeamResource(teamID, 'es',  mathMax(minStorageEnergy, startEnergyStorage * multiplier, startEnergy * multiplier, commanderMinEnergy))
			if addResources then
				Spring.SetTeamResource(teamID, 'm', startMetal * multiplier)
				Spring.SetTeamResource(teamID, 'e', startEnergy * multiplier)
			end
		end
	else
		local teamList = Spring.GetTeamList()
		for i = 1, #teamList do
			local teamID = teamList[i]

			-- Get the player's start unit to make sure staring storage is no less than its storage
			local com = UnitDefs[Spring.GetTeamRulesParam(teamID, 'startUnit')]
			if com then
				commanderMinMetal = com.metalStorage or 0
				commanderMinEnergy = com.energyStorage or 0
			end

			Spring.SetTeamResource(teamID, 'ms', mathMax(minStorageMetal, startMetalStorage, startMetal, commanderMinMetal))
			Spring.SetTeamResource(teamID, 'es',  mathMax(minStorageEnergy, startEnergyStorage,  startEnergy, commanderMinEnergy))
			if addResources then
				Spring.SetTeamResource(teamID, 'm', startMetal)
				Spring.SetTeamResource(teamID, 'e', startEnergy)
			end
		end
	end
end

function gadget:Initialize()
	if Spring.GetGameFrame() > 0 then
		return
	end
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


