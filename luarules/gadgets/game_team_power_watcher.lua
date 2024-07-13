

function gadget:GetInfo()
	return {
		name = "Team Power Watcher",
        desc = "Tracks power of individual and total units per team. To be used for PvE dynamic difficulty and library functions to assertain aspects of game progression",
		author = "SethDGamre",
		date = "2024-07-12",
		layer = 1,
		enabled = false
	}
end

if not gadgetHandler:IsSyncedCode() then return end

GG.PowerLib = {
    TeamPower = TeamPower, -- TeamPower(teamID) returns the power of the input teamID as a number

    HighestTeamPower = HighestTeamPower, --HighestTeamPower() returns the highest non scavenger/raptor team power as a table {teamID, power}

    AverageTeamPower = AverageTeamPower, --AverageTeamPower() returns the average of all non scavenger/raptor teams as a number

    LowestTeamPower = LowestTeamPower, --LowestTeamPower() returns the lowest non scavenger/raptor team power as a table {teamID, power}

    HighestHumanTeamPower = HighestHumanTeamPower, --HighestHumanTeamPower() returns the highest non AI/scavenger/raptor team power as a table {teamID, power}

    AverageHumanTeamPower = AverageHumanTeamPower, --AverageHumanTeamPower() returns the average of all non AI/scavenger/raptor teams as a number

    LowestHumanTeamPower = LowestHumanTeamPower, --LowestTeamPower() returns the lowest non AI/scavenger/raptor team power as a table {teamID, power}

    HighestAlliedTeamPower = HighestAlliedTeamPower, --HighestAlliedTeamPower(teamID) returns the highest team power of the allies belonging to input team. Returns as a table {teamID, power}

    AverageAlliedTeamPower = AverageAlliedTeamPower, -- AverageAlliedTeamPower(teamID) returns the average of all allies of the input teamID. Returns a number.

    LowestAlliedTeamPower = LowestAlliedTeamPower, --LowestAlliedTeamPower(teamID) returns the lowest of the teamID's allies power as a table {teamID, power}

    TechGuesstimate = TechGuesstimate, --TechGuesstimate(teamPower) takes an input of a power value and compares it against powerThresholds table and returns an estimated tech level from 0.5-4.5

    TeamTechGuesstimate = TeamTechGuesstimate, --TeamTechGuesstimate(teamID) takes an input teamID and compares its power against powerThresholds table and returns an estimated tech level from 0.5-4.5

    AverageTechGuesstimate = AverageTechGuesstimate, --AverageTechGuesstimate() compares average powers of all non scavenger/raptor teams against powerThresholds table and returns an estimated tech level from 0.5-4.5

    AverageHumanTechGuesstimate = AverageHumanTechGuesstimate, --AverageHumanTechGuesstimate() compares average powers of all non AI/scavenger/raptor teams against powerThresholds table and returns an estimated tech level from 0.5-4.5

    AverageAlliedTechGuesstimate = AverageAlliedTechGuesstimate, --AverageTechGuesstimate(teamID) compares average powers of all allied teams of the input teamID against powerThresholds table and returns an estimated tech level from 0.5-4.5

    TeamPeakPower = TeamPeakPower, --TeamPeakPower(teamID) returns the highest power achieved by the the input teamID as a number.

    HighestPeakPower = HighestPeakPower, --HighestPeakPower() returns the highest power achieved by any non scavenger/raptor team as a table {teamID, power}

    HighestAlliedPeakPower = HighestAlliedPeakPower, --HighestAlliedPeakPower(teamID) returns the highest power achieved by any non scavenger/raptor team on the same team as the input teamID as a table {teamID, power}

    AverageHumanPeakPower = AverageHumanPeakPower, --AverageHumanPeakPower() returns the average of all the peak powers achieved by non AI/scavenger/raptor teams as a number

    AverageAlliedPeakPower = AverageAlliedPeakPower --AverageAlliedPeakPower(teamID) returns the average of all the peak powers achieved by allied teams of the input teamID as a number.

}

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
    
    --debug

    --testPowerTable = HighestAlliedPeakPower(unitTeam)
    --Spring.Echo(UnitDefs[unitDefID].name, unitTeam, UnitDefs[unitDefID].power, teamPowers[unitTeam], "test result", testPowerTable.teamID, testPowerTable.power)

    --testPowerNumber = TechGuesstimate(teamPowers[unitTeam])
    --Spring.Echo(UnitDefs[unitDefID].name, unitTeam, UnitDefs[unitDefID].power, teamPowers[unitTeam], "test result", testPowerNumber)

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
    end
end

function TeamPower(teamID)
    for id, power in pairs(teamPowers) do
        if id == teamID then
            return power
        end
    end
    return 0
end


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



function TechGuesstimate(power)
    local techLevel = 0.5
    for _, threshold in ipairs(powerThresholds) do
        if power >= threshold.threshold then
            techLevel = threshold.techLevel
        else
            break
        end
    end

    return techLevel
end

function TeamTechGuesstimate(teamID)
    local totalPower = teamPowers[teamID]
    local techLevel = 0.5
    for _, threshold in ipairs(powerThresholds) do
        if totalPower >= threshold.threshold then
            techLevel = threshold.techLevel
        else
            break
        end
    end

    return techLevel
end


function AverageTechGuesstimate()
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(teamPowers) do
        if id ~= neutralTeamNumber and id ~= scavTeam and id ~= raptorTeam then
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


function AverageHumanTechGuesstimate()
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(teamPowers) do
        if humanTeams[id] then
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



function TeamPeakPower(teamID)
    for id, power in pairs(peakTeamPowers) do
        if id == teamID then
            return power
        end
    end
    return 0
end


function HighestPeakPower()
    local highestPower = 0
    local highestTeamID = nil

    for id, power in pairs(peakTeamPowers) do
        if id ~= neutralTeamNumber and id ~= scavTeam and id ~= raptorTeam then
            if power > highestPower then
                highestPower = power
                highestTeamID = id
            end
        end
    end

    return {teamID = highestTeamID, power = highestPower}
end


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