

function gadget:GetInfo()
	return {
		name = "Team Power Watcher",
        desc = "Tracks power of individual and total units per team, useful for PvE dynamic difficulty",
		author = "SethDGamre",
		date = "2024-07-12",
		layer = -1,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local teamList = Spring.GetTeamList()
local scavengerTeam
local raptorTeam
local aiTeams = {}
local neutralTeam
local humanTeams = {}
local teamPowers = {}
local peakTeamPowers = {}
local unitsWithPower = {}
local powerThresholds = {
    {techLevel = 1, threshold = 9000},
    {techLevel = 1.5, threshold = 45000},
    {techLevel = 2, threshold = 90000},
    {techLevel = 2.5, threshold = 230000},
    {techLevel = 3, threshold = 350000},
    {techLevel = 3.5, threshold = 475000},
    {techLevel = 4, threshold = 600000},
    {techLevel = 4.5, threshold = 725000}
}

for _, teamID in ipairs(teamList) do
    Spring.Echo("teamID", teamID)
    local teamLuaAI = Spring.GetTeamLuaAI(teamID)
    if (teamLuaAI and string.find(teamLuaAI, "ScavengersAI")) then
        scavengerTeam = teamID
    elseif (teamLuaAI and string.find(teamLuaAI, "RaptorsAI")) then
        raptorTeam = teamID
    elseif select (4, Spring.GetTeamInfo(teamID, false)) then
        aiTeams[teamID] = true
    elseif teamID == tonumber(teamList[#teamList]) then
        neutralTeam = teamID
    else
        humanTeams[teamID] = true
    end
end

--assign team powers/peak powers to 0 to prevent nil
for _, teamNumber in ipairs(teamList) do
    teamPowers[teamNumber] = 0
    peakTeamPowers[teamNumber] = 0
end



function gadget:UnitFinished(unitID, unitDefID, unitTeam)
    unitsWithPower[unitID] = { power = UnitDefs[unitDefID].power, team = unitTeam}
    teamPowers[unitTeam] = teamPowers[unitTeam] + UnitDefs[unitDefID].power
    if peakTeamPowers[unitTeam] < teamPowers[unitTeam] then
        peakTeamPowers[unitTeam] = teamPowers[unitTeam]
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
        unitsWithPower[unitID] = nil
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

--handles capture events on units already added to unitsWithPower by UnitFinished
function gadget:MetaUnitAdded(unitID, unitDefID, unitTeam)
    if unitsWithPower[unitID] then
        local oldTeam = unitsWithPower[unitID].team

        unitsWithPower[unitID] = {unitID = unitID, power = UnitDefs[unitDefID].power, team = unitTeam}
        teamPowers[unitTeam] = (teamPowers[unitTeam] + UnitDefs[unitDefID].power) or UnitDefs[unitDefID].power

        if teamPowers[oldTeam] <= UnitDefs[unitDefID].power then
            teamPowers[oldTeam] = 0
        else
            teamPowers[oldTeam] = teamPowers[unitTeam] - UnitDefs[unitDefID].power
        end

        if teamPowers[unitTeam] and peakTeamPowers[unitTeam] < teamPowers[unitTeam] then
            peakTeamPowers[unitTeam] = teamPowers[unitTeam]
        end
    end
end

--Returns the power of the input teamID as a number.
local function teamPower(teamID)
    for id, power in pairs(teamPowers) do
        if id == teamID then
            return power
        end
    end
    return 0
end

--Returns the total power of all non scavenger/raptor teams as a number.
local function totalPlayerTeamsPower()
    local totalPower = 0

    for teamID, power in pairs(teamPowers) do
        if teamID ~= neutralTeam and teamID ~= scavengerTeam and teamID ~= raptorTeam then
            totalPower = totalPower + power
        end
    end

    return totalPower
end

--Returns the highest non scavenger/raptor team power as a table {teamID, power}.
local function highestPlayerTeamPower()
    local highestPower = 0
    local highestTeamID = nil

    for teamID, power in pairs(teamPowers) do
        if teamID ~= neutralTeam and teamID ~= scavengerTeam and teamID ~= raptorTeam then
            if power > highestPower then
                highestPower = power
                highestTeamID = teamID
            end
        end
    end

    return {teamID = highestTeamID, power = highestPower}
end

--Returns the average of all non scavenger/raptor teams as a number.
local function averagePlayerTeamPower()
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(teamPowers) do
        if id ~= neutralTeam and id ~= scavengerTeam and id ~= raptorTeam then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = totalPower / teamCount
    return averagePower
end

--Returns the lowest non scavenger/raptor team power as a table {teamID, power}.
local function lowestPlayerTeamPower()
    local lowestPower = math.huge
    local lowestTeamID = nil

    for teamID, power in pairs(teamPowers) do
        if teamID ~= neutralTeam and teamID ~= scavengerTeam and teamID ~= raptorTeam then
            if power < lowestPower then
                lowestPower = power
                lowestTeamID = teamID
            end
        end
    end

    return {teamID = lowestTeamID, power = lowestPower}
end

--Returns the highest non AI/scavenger/raptor team power as a table {teamID, power}.
local function highestHumanTeamPower()
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

--Returns the average of all non AI/scavenger/raptor teams as a number.
local function averageHumanTeamPower()
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

--Returns the lowest non AI/scavenger/raptor team power as a table {teamID, power}.
local function lowestHumanTeamPower()
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

--Returns the highest team power of the allies belonging to input team. Returns as a table {teamID, power}.
local function highestAlliedTeamPower(teamID)
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

--Returns the average of all allies of the input teamID. Returns a number.
local function averageAlliedTeamPower(teamID) 
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

--Returns the lowest of the teamID's allies power as a table {teamID, power}.
local function lowestAlliedTeamPower(teamID)
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

--Takes an input of a power value and compares it against powerThresholds table and returns an estimated tech level from 0.5-4.5.
local function techGuesstimate(power)
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

--Takes an input teamID and compares its power against powerThresholds table and returns an estimated tech level from 0.5-4.5.
local function teamTechGuesstimate(teamID)
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

--Compares average powers of all non scavenger/raptor teams against powerThresholds table and returns an estimated tech level from 0.5-4.5.
local function averagePlayerTechGuesstimate()
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(teamPowers) do
        if id ~= neutralTeam and id ~= scavengerTeam and id ~= raptorTeam then
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

--Compares average powers of all non AI/scavenger/raptor teams against powerThresholds table and returns an estimated tech level from 0.5-4.5.
local function averageHumanTechGuesstimate()
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

--Compares average powers of all allied teams of the input teamID against powerThresholds table and returns an estimated tech level from 0.5-4.5
local function averageAlliedTechGuesstimate(teamID)
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

--Returns the highest power achieved by the the input teamID as a number.
local function teamPeakPower(teamID)
    for id, power in pairs(peakTeamPowers) do
        if id == teamID then
            return power
        end
    end
    return 0
end

--Returns the total peak power achieved by all non scavenger/raptor teams as a number.
local function totalPlayerPeakPower()
    local totalPeakPower = 0

    for id, power in pairs(peakTeamPowers) do
        if id ~= neutralTeam and id ~= scavengerTeam and id ~= raptorTeam then
            totalPeakPower = totalPeakPower + power
        end
    end

    return totalPeakPower
end

--Returns the highest power achieved by any non scavenger/raptor team as a table {teamID, power}.
local function highestPlayerPeakPower() 
    local highestPower = 0
    local highestTeamID = nil

    for id, power in pairs(peakTeamPowers) do
        if id ~= neutralTeam and id ~= scavengerTeam and id ~= raptorTeam then
            if power > highestPower then
                highestPower = power
                highestTeamID = id
            end
        end
    end

    return {teamID = highestTeamID, power = highestPower}
end

--Returns the highest power achieved by any non scavenger/raptor team on the same team as the input teamID as a table {teamID, power}.
local function highestAlliedPeakPower(teamID) 
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

--Returns the average of all the peak powers achieved by non AI/scavenger/raptor teams as a number.
local function averageHumanPeakPower()
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

--Returns the average of all the peak powers achieved by allied teams of the input teamID as a number.
local function averageAlliedPeakPower(teamID)
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



function gadget:Initialize()
    GG.PowerLib = {}
    GG.PowerLib["TeamList"] = teamList
    GG.PowerLib["ScavengerTeam"] = scavengerTeam
    GG.PowerLib["RaptorTeam"] = raptorTeam
    GG.PowerLib["AiTeams"] = aiTeams
    GG.PowerLib["NeutralTeam"] = neutralTeam
    GG.PowerLib["HumanTeams"] = humanTeams
    GG.PowerLib["TeamPowers"] = teamPowers
    GG.PowerLib["PeakTeamPowers"] = peakTeamPowers
    GG.PowerLib["UnitsWithPower"] = unitsWithPower
    GG.PowerLib["PowerThresholds"] = powerThresholds
    GG.PowerLib["TeamPower"] = teamPower
    GG.PowerLib["TotalPlayerTeamsPower"] = totalPlayerTeamsPower
    GG.PowerLib["HighestPlayerTeamPower"] = highestPlayerTeamPower
    GG.PowerLib["AveragePlayerTeamPower"] = averagePlayerTeamPower
    GG.PowerLib["LowestPlayerTeamPower"] = lowestPlayerTeamPower
    GG.PowerLib["HighestHumanTeamPower"] = highestHumanTeamPower
    GG.PowerLib["AverageHumanTeamPower"] = averageHumanTeamPower
    GG.PowerLib["LowestHumanTeamPower"] = lowestHumanTeamPower
    GG.PowerLib["HighestAlliedTeamPower"] = highestAlliedTeamPower
    GG.PowerLib["AverageAlliedTeamPower"] = averageAlliedTeamPower
    GG.PowerLib["LowestAlliedTeamPower"] = lowestAlliedTeamPower
    GG.PowerLib["TechGuesstimate"] = techGuesstimate
    GG.PowerLib["TeamTechGuesstimate"] = teamTechGuesstimate
    GG.PowerLib["AveragePlayerTechGuesstimate"] = averagePlayerTechGuesstimate
    GG.PowerLib["AverageHumanTechGuesstimate"] = averageHumanTechGuesstimate
    GG.PowerLib["AverageAlliedTechGuesstimate"] = averageAlliedTechGuesstimate
    GG.PowerLib["TeamPeakPower"] = teamPeakPower
    GG.PowerLib["TotalPlayerPeakPower"] = totalPlayerPeakPower
    GG.PowerLib["HighestPlayerPeakPower"] = highestPlayerPeakPower
    GG.PowerLib["HighestAlliedPeakPower"] = highestAlliedPeakPower
    GG.PowerLib["AverageHumanPeakPower"] = averageHumanPeakPower
    GG.PowerLib["AverageAlliedPeakPower"] = averageAlliedPeakPower
end
