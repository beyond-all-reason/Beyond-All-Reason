

function gadget:GetInfo()
	return {
		name = "Team Power Watcher",
        desc = "Tracks power of individual and total units per team. To be used for PvE dynamic difficulty and library functions to assertain aspects of game progression",
		author = "SethDGamre",
		date = "2024-07-12",
		layer = 1,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local spGetGameFrame          = Spring.GetGameFrame
local spSetUnitRulesParam     = Spring.SetUnitRulesParam
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetTeamResources = Spring.GetTeamResources --(teamID, "metal"|"energy") return nil | currentLevel
local spGetUnitDefID        = Spring.GetUnitDefID

local spGetTeamList			= Spring.GetTeamList
local spGetUnitTeam 		= Spring.GetUnitTeam

local spGetGameSeconds = Spring.GetGameSeconds

local random = math.random
local math_min = math.min
local sin    = math.sin
local cos    = math.cos

local GAME_SPEED = Game.gameSpeed

local unitsWithPower = {}
local teamList = spGetTeamList()
local neutralTeamNumber
local teamPowers = {}
local highestTeamPower = {}
local averageTeamPower = 0
local averageAlliedTeamPower = 0
local averageHumanTeamPower = 0
local averageTechGuesstimate = 0
local averageAlliedTechGuesstimate = 0
local averageHumanTechGuesstimate = 0
local peakTeamPowers = {}
local highestPeakPower = {}
local averagePeakPower = 0
local averagePeakAlliedPower = 0

--AI team lists
local scavTeam
local raptorTeam
local AIteams = {}
local humanTeams = {}


--used for tech level guesstimate functions
local powerThresholds = {
    {threshold = 9000, techLevel = 1},
    {threshold = 45000, techLevel = 1.5},
    {threshold = 90000, techLevel = 2},
    {threshold = 230000, techLevel = 2.5},
    {threshold = 350000, techLevel = 3},
    {threshold = 475000, techLevel = 3.5},
    {threshold = 600000, techLevel = 4},
    {threshold = 725000, techLevel = 4.5}
}


--decipher human vs ai vs neutral vs defense mode ai's 
for _, teamID in ipairs(teamList) do
    local teamLuaAI = Spring.GetTeamLuaAI(teamID)
    if (teamLuaAI and string.find(teamLuaAI, "ScavengersAI")) then
        scavTeam = teamID
    elseif (teamLuaAI and string.find(teamLuaAI, "RaptorsAI")) then
        raptorTeam = teamID
    elseif select (4, Spring.GetTeamInfo(teamID, false)) then
        AIteams[teamID] = true
    elseif teamID == tonumber(teamList[#teamList]) then
        neutralTeamNumber = teamID
    else
        humanTeams[teamID] = true
    end
end

--assign all teams power and peak power of 0 to prevent nil errors
for _, teamNumber in ipairs(teamList) do
    teamPowers[teamNumber] = 0
    peakTeamPowers[teamNumber] = 0
end



function gadget:UnitFinished(unitID, unitDefID, unitTeam)
    unitsWithPower[unitID] = {unitID = unitID, power = UnitDefs[unitDefID].power, team = unitTeam}
    teamPowers[unitTeam] = (teamPowers[unitTeam] + UnitDefs[unitDefID].power) or UnitDefs[unitDefID].power
    
    --temporary
    highestTeamPower = HighestTeamPower()
    averageTeamPower = AverageTeamPower()
    averageHumanTeamPower = AverageHumanTeamPower(unitTeam)
    averageAlliedTeamPower = AverageAlliedTeamPower(unitTeam)
    averageTechGuesstimate = AverageTechGuesstimate()
    averageAlliedTechGuesstimate = AverageAlliedTechGuesstimate(unitTeam)
    averageHumanTechGuesstimate = AverageHumanTechGuesstimate()
    --not tested yet
    highestPeakPower = HighestPeakPower()
    averagePeakPower = AveragePeakHumanPower()
    averagePeakAlliedPower = AveragePeakAlliedPower(unitTeam)

    --update peak powers
    if teamPowers[unitTeam] and peakTeamPowers[unitTeam] < teamPowers[unitTeam] then
        peakTeamPowers[unitTeam] = teamPowers[unitTeam]
    end


    --Debug row, eventually to be replaced with %frame triggered calculation events
    --Spring.Echo(UnitDefs[unitDefID].name, unitTeam, UnitDefs[unitDefID].power, teamPowers[unitTeam], "highest", highestTeamPower.teamID, highestTeamPower.power)
    --Spring.Echo(UnitDefs[unitDefID].name, unitTeam, UnitDefs[unitDefID].power, teamPowers[unitTeam], "averageTeamPower", averageTeamPower)
    --Spring.Echo(UnitDefs[unitDefID].name, unitTeam, UnitDefs[unitDefID].power, teamPowers[unitTeam], "averageAlliedTeamPower", averageAlliedTeamPower)
    --Spring.Echo(UnitDefs[unitDefID].name, unitTeam, UnitDefs[unitDefID].power, teamPowers[unitTeam], "averageTechGuesstimate", averageTechGuesstimate)
    --Spring.Echo(UnitDefs[unitDefID].name, unitTeam, UnitDefs[unitDefID].power, teamPowers[unitTeam], "averageHumanTechGuesstimate", averageHumanTechGuesstimate)
    --Spring.Echo(UnitDefs[unitDefID].name, unitTeam, UnitDefs[unitDefID].power, teamPowers[unitTeam], "averageAlliedTechGuesstimate", averageAlliedTechGuesstimate)
    --Spring.Echo(UnitDefs[unitDefID].name, unitTeam, UnitDefs[unitDefID].power, teamPowers[unitTeam], "peakTeamPowers", peakTeamPowers[unitTeam])
end



function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
    if unitsWithPower[unitID] then
        unitsWithPower[unitID] = nil
    end
    if UnitDefs[unitDefID].power then
        if teamPowers[unitTeam] then
            if teamPowers[unitTeam] <= UnitDefs[unitDefID].power then
                teamPowers[unitTeam] = 0
            else
                teamPowers[unitTeam] = teamPowers[unitTeam] - UnitDefs[unitDefID].power
            end
        end
        --Spring.Echo(UnitDefs[unitDefID].name, unitTeam, UnitDefs[unitDefID].power, teamPowers[unitTeam])
    end
end



function HighestTeamPower()
    local power = 0
    local teamID = nil

    for t, p in pairs(teamPowers) do
        if id ~= neutralTeamNumber and id ~= scavTeam and id ~= raptorTeam then
            if p > power then
                power = p
                teamID = t
            end
        end
    end

    return {teamID = teamID, power = power}
end



function AverageTeamPower()
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(teamPowers) do
        if id ~= neutralTeamNumber and id ~= scavTeam and id ~= raptorTeam then
            --Spring.Echo("Average Power Team Factored", id)
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = totalPower / teamCount
    return averagePower
end



function AverageAlliedTeamPower(teamID)
    local allyTeamNum = select(6, Spring.GetTeamInfo(teamID))
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(teamPowers) do
        if allyTeamNum == select(6, Spring.GetTeamInfo(id)) then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = totalPower / teamCount
    return averagePower
end

function AverageHumanTeamPower(teamID)
    local allyTeamNum = select(6, Spring.GetTeamInfo(teamID))
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(teamPowers) do
        if humanTeams[id] then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = totalPower / teamCount
    return averagePower
end



function AverageTechGuesstimate() --Excludes Neutral, Scavengers and Raptors. Guesses an equivalent average tech level based on power for all teams.
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(teamPowers) do
        if id ~= neutralTeamNumber and id ~= scavTeam and id ~= raptorTeam then
            --Spring.Echo("Average Tech Guess Team Factored", id)
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = totalPower / teamCount

    local techLevel = 0.5
    for _, threshold in ipairs(powerThresholds) do
        if averagePower >= threshold.threshold then
            techLevel = threshold.techLevel
        else
            break
        end
    end

    return techLevel
end



function AverageHumanTechGuesstimate() --Excludes AI's, Neutral, Scavengers and Raptors. Guesses an equivalent average tech level based on power for all humans.
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(teamPowers) do
        if humanTeams[id] then
            Spring.Echo("Average HUMAN Tech Guess Team Factored", id)
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = totalPower / teamCount

    local techLevel = 0.5
    for _, threshold in ipairs(powerThresholds) do
        if averagePower >= threshold.threshold then
            techLevel = threshold.techLevel
        else
            break
        end
    end

    return techLevel
end



function AverageAlliedTechGuesstimate(teamID) --Excludes Neutral, Scavengers and Raptors. Guesses an equivalent average tech level based on power for all allied teams.
    local allyTeamNum = select(6, Spring.GetTeamInfo(teamID))
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(teamPowers) do
        if allyTeamNum == select(6, Spring.GetTeamInfo(id)) then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = totalPower / teamCount

    local techLevel = 0.5
    for _, threshold in ipairs(powerThresholds) do
        if averagePower >= threshold.threshold then
            techLevel = threshold.techLevel
        else
            break
        end
    end

    return techLevel
end



function HighestPeakPower()
    local highestPower = 0
    local highestTeamID = nil

    for teamID, power in pairs(peakTeamPowers) do
        if power > highestPower then
            highestPower = power
            highestTeamID = teamID
        end
    end

    return {teamID = highestTeamID, power = highestPower}
end



function AveragePeakHumanPower()
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(peakTeamPowers) do
        if humanTeams[id] then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = totalPower / teamCount
    return averagePower
end



function AveragePeakAlliedPower(teamID)
    local allyTeamNum = select(6, Spring.GetTeamInfo(teamID))
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(teamPowers) do
        if allyTeamNum == select(6, Spring.GetTeamInfo(id)) then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = totalPower / teamCount
    return averagePower
end