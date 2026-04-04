local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name = 'Team Resourcing',
        desc = 'Sets up team resources',
        author = 'Niobium, Maxie12',
        date = 'May 2011',  -- November 2025
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


local function GetTeamPlayerCounts()
    local teamPlayerCounts = {}
    local playerList = SpringShared.GetPlayerList()
    for i = 1, #playerList do
        local playerID = playerList[i]
        local _, _, isSpec, teamID = SpringShared.GetPlayerInfo(playerID, false)
        if not isSpec then
            teamPlayerCounts[teamID] = (teamPlayerCounts[teamID] or 0) + 1
        end
    end
    return teamPlayerCounts
end

local function setup(addResources)
    local startMetalStorage = SpringShared.GetModOptions().startmetalstorage
    local startEnergyStorage = SpringShared.GetModOptions().startenergystorage
    local startMetal = SpringShared.GetModOptions().startmetal
    local startEnergy = SpringShared.GetModOptions().startenergy
    local bonusMultiplierEnabled = SpringShared.GetModOptions().bonusstartresourcemultiplier;

    local commanderMinMetal, commanderMinEnergy = 0, 0

    -- Coop mode specific modification. Store amount of non-spectating players per team
    local teamPlayerCounts = {}
    if GG.coopMode then
        teamPlayerCounts = GetTeamPlayerCounts()
    end

    local teamList = SpringShared.GetTeamList()
    for i = 1, #teamList do
        local teamID = teamList[i]

        -- If coopmode is enabled, multiplier depending on player count.
        local multiplier = 1
        if GG.coopMode then
            multiplier = teamPlayerCounts[teamID] or 1 -- Gaia has no players	
        end

        --If starting bonus multiplication is enabled, multiply it.
        local teamMultiplier = 1;
        if (bonusMultiplierEnabled) then
            teamMultiplier = select(7, SpringShared.GetTeamInfo(teamID));
        end

        -- Get starting resources and storage including any bonuses from mods
        local startingMetal = startMetal * teamMultiplier * multiplier
        local startingEnergy = startEnergy * teamMultiplier * multiplier
        local startingMetalStorage = startMetalStorage * teamMultiplier * multiplier
        local startingEnergyStorage = startEnergyStorage * teamMultiplier * multiplier

        -- Get the player's start unit to make sure starting storage is no less than its storage
        local com = UnitDefs[SpringShared.GetTeamRulesParam(teamID, 'startUnit')]
        if com then
            commanderMinMetal = com.metalStorage or 0
            commanderMinEnergy = com.energyStorage or 0
        end

        SpringSynced.SetTeamResource(teamID, 'ms', mathMax(minStorageMetal, startingMetalStorage, startingMetal, commanderMinMetal))
        SpringSynced.SetTeamResource(teamID, 'es', mathMax(minStorageEnergy, startingEnergyStorage, startingEnergy, commanderMinEnergy))
        if addResources then
            SpringSynced.SetTeamResource(teamID, 'm', startingMetal)
            SpringSynced.SetTeamResource(teamID, 'e', startingEnergy)
        end
    end
end

function gadget:Initialize()
    if SpringShared.GetGameFrame() > 0 then
        return
    end
    setup(true)
end

function gadget:GameStart()
    -- reset because commander added additional storage as well
    setup()
end

function gadget:TeamDied(teamID)
    SpringSynced.SetTeamShareLevel(teamID, 'metal', 0)
    SpringSynced.SetTeamShareLevel(teamID, 'energy', 0)
end
