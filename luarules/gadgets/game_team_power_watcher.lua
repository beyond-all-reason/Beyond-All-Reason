

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

GG.TeamPower = {
    TeamPower = TeamPower,
    HighestTeamPower = HighestTeamPower,
    AverageTeamPower = AverageTeamPower,
    LowestTeamPower = LowestTeamPower,
    HighestHumanTeamPower = HighestHumanTeamPower,
    AverageHumanTeamPower = AverageHumanTeamPower,
    LowestHumanTeamPower = LowestHumanTeamPower,
    HighestAlliedTeamPower = HighestAlliedTeamPower,
    AverageAlliedTeamPower = AverageAlliedTeamPower,
    LowestAlliedTeamPower = LowestAlliedTeamPower,
    AverageTechGuesstimate = AverageTechGuesstimate,
    AverageHumanTechGuesstimate = AverageHumanTechGuesstimate,
    AverageAlliedTechGuesstimate = AverageAlliedTechGuesstimate,
    TeamPeakPower = TeamPeakPower,
    HighestPeakPower = HighestPeakPower,
    HighestAlliedPeakPower = HighestAlliedPeakPower,
    AverageHumanPeakPower = AverageHumanPeakPower,
    AverageAlliedPeakPower = AverageAlliedPeakPower
}

local spGetGameSeconds = Spring.GetGameSeconds

local unitsWithPower = {}
local teamList = Spring.GetTeamList()
local neutralTeamNumber
local teamPowers = {}
local peakTeamPowers = {}

local testPowerTable = {}
local testPowerNumber = 0

--AI team lists
local scavTeam
local raptorTeam
local AIteams = {}
local humanTeams = {}


--used for tech level guesstimate functions last updated 7/12/24
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
    testPowerTable = HighestAlliedPeakPower(unitTeam)
    --Spring.Echo(UnitDefs[unitDefID].name, unitTeam, UnitDefs[unitDefID].power, teamPowers[unitTeam], "test result", testPowerTable.teamID, testPowerTable.power)

    testPowerNumber = AverageAlliedPeakPower(unitTeam)
    Spring.Echo(UnitDefs[unitDefID].name, unitTeam, UnitDefs[unitDefID].power, teamPowers[unitTeam], "test result", testPowerNumber)


    --update peak powers
    if teamPowers[unitTeam] and peakTeamPowers[unitTeam] < teamPowers[unitTeam] then
        peakTeamPowers[unitTeam] = teamPowers[unitTeam]
    end
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

--t
function TeamPower(teamID)
    for id, power in pairs(teamPowers) do
        if id == teamID then
            return power
        end
    end
    return 0
end

--t
function HighestTeamPower()
    local highestPower = 0
    local highestTeamID = nil

    for teamID, power in pairs(teamPowers) do
        if teamID ~= neutralTeamNumber and teamID ~= scavTeam and teamID ~= raptorTeam then
            if power > highestPower then
                highestPower = power
                highestTeamID = teamID
            end
        end
    end

    return {teamID = highestTeamID, power = highestPower}
end

--t
function AverageTeamPower()
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(teamPowers) do
        if id ~= neutralTeamNumber and id ~= scavTeam and id ~= raptorTeam then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = totalPower / teamCount
    return averagePower
end

--t
function LowestTeamPower()
    local lowestPower = math.huge
    local lowestTeamID = nil

    for teamID, power in pairs(teamPowers) do
        if teamID ~= neutralTeamNumber and teamID ~= scavTeam and teamID ~= raptorTeam then
            if power < lowestPower then
                lowestPower = power
                lowestTeamID = teamID
            end
        end
    end

    return {teamID = lowestTeamID, power = lowestPower}
end


--t
function HighestHumanTeamPower()
    local highestPower = 0
    local highestTeamID = nil

    for teamID, power in pairs(teamPowers) do
        if humanTeams[teamID] then
            if power > highestPower then
                highestPower = power
                highestTeamID = teamID
            end
        end
    end

    return {teamID = highestTeamID, power = highestPower}
end

--t
function AverageHumanTeamPower()
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

--t
function LowestHumanTeamPower()
    local lowestPower = math.huge
    local lowestTeamID = nil

    for teamID, power in pairs(teamPowers) do
        if humanTeams[teamID] then
            if power < lowestPower then
                lowestPower = power
                lowestTeamID = teamID
            end
        end
    end

    return {teamID = lowestTeamID, power = lowestPower}
end


--t
function HighestAlliedTeamPower(teamID)
    local allyTeamNum = select(6, Spring.GetTeamInfo(teamID))
    local highestPower = 0
    local highestTeamID = nil

    for id, power in pairs(teamPowers) do
        if allyTeamNum == select(6, Spring.GetTeamInfo(id)) then
            if power > highestPower then
                highestPower = power
                highestTeamID = id
            end
        end
    end

    return {teamID = highestTeamID, power = highestPower}
end

--t
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

--t
function LowestAlliedTeamPower(teamID)
    local allyTeamNum = select(6, Spring.GetTeamInfo(teamID))
    local lowestPower = math.huge
    local lowestTeamID = nil

    for id, power in pairs(teamPowers) do
        if allyTeamNum == select(6, Spring.GetTeamInfo(id)) then
            if power < lowestPower then
                lowestPower = power
                lowestTeamID = id
            end
        end
    end

    return {teamID = lowestTeamID, power = lowestPower}
end


--t
function AverageTechGuesstimate()
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

--t
function AverageHumanTechGuesstimate()
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

--t
function AverageAlliedTechGuesstimate(teamID)
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


--t
function TeamPeakPower(teamID)
    for id, power in pairs(peakTeamPowers) do
        if id == teamID then
            return power
        end
    end
    return 0
end

--t
function HighestPeakPower()
    local highestPower = 0
    local highestTeamID = nil

    for id, power in pairs(peakTeamPowers) do
        if power > highestPower then
            highestPower = power
            highestTeamID = id
        end
    end

    return {teamID = highestTeamID, power = highestPower}
end

--t
function HighestAlliedPeakPower(teamID)
    local allyTeamNum = select(6, Spring.GetTeamInfo(teamID))
    local highestPower = 0
    local highestTeamID = nil

    for id, power in pairs(peakTeamPowers) do
        if allyTeamNum == select(6, Spring.GetTeamInfo(id)) then
            if power > highestPower then
                highestPower = power
                highestTeamID = id
            end
        end
    end

    return {teamID = highestTeamID, power = highestPower}
end

--t
function AverageHumanPeakPower()
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

--t
function AverageAlliedPeakPower(teamID)
    local allyTeamNum = select(6, Spring.GetTeamInfo(teamID))
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(peakTeamPowers) do
        if allyTeamNum == select(6, Spring.GetTeamInfo(id)) then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = totalPower / teamCount
    return averagePower
end