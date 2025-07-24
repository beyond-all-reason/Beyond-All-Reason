

local gadget = gadget ---@type Gadget

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

local teamIsOverPoweredRatio = 1.25
local alliesAreWinningRatio = 1.25

local teamList = Spring.GetTeamList()
local scavengerTeam
local raptorTeam
local aiTeams = {}
local neutralTeam
local humanTeams = {}
local playerTeams = {}
local teamPowers = {}
local peakTeamPowers = {}
local unitsWithPower = {}
local playerAllies = {}
local powerThresholds = {
    {techLevel = 0.5, threshold = 0},
    {techLevel = 1, threshold = 9000},
    {techLevel = 1.5, threshold = 45000},
    {techLevel = 2, threshold = 90000},
    {techLevel = 2.5, threshold = 230000},
    {techLevel = 3, threshold = 350000},
    {techLevel = 3.5, threshold = 475000},
    {techLevel = 4, threshold = 600000},
    {techLevel = 4.5, threshold = 725000}
}

local pveTeamID = scavengerTeam or raptorTeam
local scavengerTeam = Spring.Utilities.GetScavTeamID()
local raptorTeam = Spring.Utilities.GetRaptorTeamID()
for _, teamID in ipairs(teamList) do
    local allyID = select(6, Spring.GetTeamInfo(teamID))
    if teamID ~= scavengerTeam and teamID ~= raptorTeam and select (4, Spring.GetTeamInfo(teamID, false)) then
        aiTeams[teamID] = true
        playerTeams[teamID] = true
        playerAllies[allyID] = playerAllies[allyID] or {}
        playerAllies[allyID][teamID] = true
    elseif teamID == tonumber(teamList[#teamList]) then
        neutralTeam = teamID
    else
        humanTeams[teamID] = true
        playerTeams[teamID] = true
        playerAllies[allyID] = playerAllies[allyID] or {}
        playerAllies[allyID][teamID] = true
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

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
        unitsWithPower[unitID] = nil
            teamPowers[unitTeam] = math.max(teamPowers[unitTeam] - UnitDefs[unitDefID].power, 0)
end

--handles capture events on units already added to unitsWithPower by UnitFinished
function gadget:MetaUnitAdded(unitID, unitDefID, unitTeam)
    if unitsWithPower[unitID] then
        local oldTeam = unitsWithPower[unitID].team

        unitsWithPower[unitID] = { power = UnitDefs[unitDefID].power, team = unitTeam}
        teamPowers[unitTeam] = teamPowers[unitTeam] + UnitDefs[unitDefID].power

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

local function isPlayerTeam(teamID)
    return teamID ~= neutralTeam and teamID ~= scavengerTeam and teamID ~= raptorTeam
end

-- Returns the power of the input teamID as a number.
local function teamPower(teamID)
   return teamPowers[teamID]
end

-- Returns the total power of all non scavenger/raptor teams as a number.
local function totalPlayerTeamsPower()
    local totalPower = 0

    for teamID, power in pairs(teamPowers) do
        if isPlayerTeam(teamID) then
            totalPower = totalPower + power
        end
    end

    return totalPower
end

-- Returns the highest non scavenger/raptor team power as a table {teamID, power}.
local function highestPlayerTeamPower()
    local highestPower = 0
    local highestTeamID = nil

    for teamID, power in pairs(teamPowers) do
        if isPlayerTeam(teamID) then
            if power > highestPower then
                highestPower = power
                highestTeamID = teamID
            end
        end
    end

    return {teamID = highestTeamID, power = highestPower}
end

-- Returns the average of all non scavenger/raptor teams as a number.
local function averagePlayerTeamPower()
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(teamPowers) do
        if isPlayerTeam(id) and power > 0 then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = teamCount > 0 and totalPower / teamCount or 0
    return averagePower
end

-- Returns the lowest non scavenger/raptor team power as a table {teamID, power}.
local function lowestPlayerTeamPower()
    local lowestPower = math.huge
    local lowestTeamID = nil

    for teamID, power in pairs(teamPowers) do
        if isPlayerTeam(teamID) and power > 0 then
            if power < lowestPower then
                lowestPower = power
                lowestTeamID = teamID
            end
        end
    end

    return {teamID = lowestTeamID, power = lowestPower}
end

-- Returns the highest non AI/scavenger/raptor team power as a table {teamID, power}.
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

-- Returns the average of all non AI/scavenger/raptor teams as a number.
local function averageHumanTeamPower()
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(teamPowers) do
        if humanTeams[id] and power > 0 then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = teamCount > 0 and totalPower / teamCount or 0
    return averagePower
end

-- Returns the lowest non AI/scavenger/raptor team power as a table {teamID, power}.
local function lowestHumanTeamPower()
    local lowestPower = math.huge
    local lowestTeamID = nil

    for teamID, power in pairs(teamPowers) do
        if humanTeams[teamID] and power > 0 then
            if power < lowestPower then
                lowestPower = power
                lowestTeamID = teamID
            end
        end
    end

    return {teamID = lowestTeamID, power = lowestPower}
end

-- Returns the highest team power of the allies belonging to input team or allyID. Returns as a table {teamID, power}.
local function highestAlliedTeamPower(teamID, allyID)
    allyID = allyID or select(6, Spring.GetTeamInfo(teamID))
    local highestPower = 0
    local highestTeamID = nil

    for id, power in pairs(teamPowers) do
        if allyID == select(6, Spring.GetTeamInfo(id)) and power > 0 then
            if power > highestPower then
                highestPower = power
                highestTeamID = id
            end
        end
    end

    return {teamID = highestTeamID, power = highestPower}
end

-- Returns the average of all allies of the input teamID or allyID. Returns a number.
local function averageAlliedTeamPower(teamID, allyID) 
    allyID = allyID or select(6, Spring.GetTeamInfo(teamID))
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(teamPowers) do
        if allyID == select(6, Spring.GetTeamInfo(id)) and power > 0 then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = teamCount > 0 and totalPower / teamCount or 0
    return averagePower
end

-- Returns the lowest of the teamID's allies or allyID's power as a table {teamID, power}.
local function lowestAlliedTeamPower(teamID, allyID)
    allyID = allyID or select(6, Spring.GetTeamInfo(teamID))
    local lowestPower = math.huge
    local lowestTeamID = nil

    for id, power in pairs(teamPowers) do
        if allyID == select(6, Spring.GetTeamInfo(id)) and power > 0 then
            if power < lowestPower then
                lowestPower = power
                lowestTeamID = id
            end
        end
    end

    return {teamID = lowestTeamID, power = lowestPower}
end

-- Take an input of a power value and return an estimated tech level number.
local function techGuesstimate(power)
    local techLevel = 0
    for _, threshold in ipairs(powerThresholds) do
        if power >= threshold.threshold then
            techLevel = threshold.techLevel
        else
            break
        end
    end

    return techLevel
end

-- Takes an input teamID return an estimated tech level number.
local function teamTechGuesstimate(teamID)
    local totalPower = teamPowers[teamID]
    local techLevel = 0
    for _, threshold in ipairs(powerThresholds) do
        if totalPower >= threshold.threshold then
            techLevel = threshold.techLevel
        else
            break
        end
    end

    return techLevel
end

-- Calculate all average powers of all non scavenger/raptor teams and return an estimated tech level number.
local function averagePlayerTechGuesstimate()
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(teamPowers) do
        if isPlayerTeam(id) and power > 0 then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = teamCount > 0 and totalPower / teamCount or 0

    local techLevel = 0
    for _, threshold in ipairs(powerThresholds) do
        if averagePower >= threshold.threshold then
            techLevel = threshold.techLevel
        else
            break
        end
    end

    return techLevel
end

-- Compares average powers of all non AI/scavenger/raptor teams return an estimated tech level number.
local function averageHumanTechGuesstimate()
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(teamPowers) do
        if humanTeams[id] and power > 0 then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = teamCount > 0 and totalPower / teamCount or 0

    local techLevel = 0
    for _, threshold in ipairs(powerThresholds) do
        if averagePower >= threshold.threshold then
            techLevel = threshold.techLevel
        else
            break
        end
    end

    return techLevel
end

-- Compare average powers of all allied teams of the input teamID or allyID  and return an estimated tech level number.
local function averageAlliedTechGuesstimate(teamID, allyID)
    allyID = allyID or select(6, Spring.GetTeamInfo(teamID))
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(teamPowers) do
        if allyID == select(6, Spring.GetTeamInfo(id)) and power > 0 then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = teamCount > 0 and totalPower / teamCount or 0

    local techLevel = 0
    for _, threshold in ipairs(powerThresholds) do
        if averagePower >= threshold.threshold then
            techLevel = threshold.techLevel
        else
            break
        end
    end

    return techLevel
end

-- Returns the highest power achieved by the the input teamID as a number.
local function teamPeakPower(teamID)
    for id, power in pairs(peakTeamPowers) do
        if id == teamID then
            return power
        end
    end
    return 0
end

-- Returns the total peak power achieved by all non scavenger/raptor teams as a number.
local function totalPlayerPeakPower()
    local totalPeakPower = 0

    for id, power in pairs(peakTeamPowers) do
        if isPlayerTeam(id) then
            totalPeakPower = totalPeakPower + power
        end
    end

    return totalPeakPower
end

-- Returns the highest power achieved by any non scavenger/raptor team as a table {teamID, power}.
local function highestPlayerPeakPower() 
    local highestPower = 0
    local highestTeamID = nil

    for id, power in pairs(peakTeamPowers) do
        if isPlayerTeam(id) then
            if power > highestPower then
                highestPower = power
                highestTeamID = id
            end
        end
    end

    return {teamID = highestTeamID, power = highestPower}
end

-- Returns the highest power achieved by any non scavenger/raptor team on the same team as the input teamID or allyID  as a table {teamID, power}.
local function highestAlliedPeakPower(teamID, allyID) 
    allyID = allyID or select(6, Spring.GetTeamInfo(teamID))
    local highestPower = 0
    local highestTeamID = nil

    for id, power in pairs(peakTeamPowers) do
        if allyID == select(6, Spring.GetTeamInfo(id)) then
            if power > highestPower then
                highestPower = power
                highestTeamID = id
            end
        end
    end

    return {teamID = highestTeamID, power = highestPower}
end

-- Returns the average of all the peak powers achieved by non AI/scavenger/raptor teams as a number.
local function averageHumanPeakPower()
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(peakTeamPowers) do
        if humanTeams[id] then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = teamCount > 0 and totalPower / teamCount or 0
    return averagePower
end

-- Returns the average of all the peak powers achieved by allied teams of the input teamID or allyID as a number.
local function averageAlliedPeakPower(teamID, allyID)
    allyID = allyID or select(6, Spring.GetTeamInfo(teamID))
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(peakTeamPowers) do
        if allyID == select(6, Spring.GetTeamInfo(id)) then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = teamCount > 0 and totalPower / teamCount or 0
    return averagePower
end

-- Returns the ratio number of the input teamID compared to the average of all players.
local function teamComparedToAveragedPlayers(teamID)
    local totalPower = 0
    local teamCount = 0
    local teamPower = teamPowers[teamID]

    for id, power in pairs(teamPowers) do
        if playerTeams[id] and power > 0 then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = teamCount > 0 and totalPower / teamCount or 0

    local ratio = averagePower > 0 and teamPower / averagePower or 0
    return ratio
end

-- Returns boolean true if the input teamID is considered significantly more powerful by the API. Second argument allows user-defined ratio.
local function isTeamOverPowered(teamID, marginRatio)
    marginRatio = marginRatio or teamIsOverPoweredRatio
    local totalPower = 0
    local teamCount = 0
    local teamPower = teamPowers[teamID]

    for id, power in pairs(teamPowers) do
        if playerTeams[id] and power > 0 then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = teamCount > 0 and totalPower / teamCount or 0

    local ratio = averagePower > 0 and teamPower / averagePower or 0
    if marginRatio and ratio > marginRatio then
        return true
    else
        return false
    end
end

-- Returns the ratio number of the input teamID's allies or allyID compared to the average of all player allies.
local function alliesComparedToAverage(teamID, allyID)
    allyID = allyID or select(6, Spring.GetTeamInfo(teamID))
    local allyPowers = {}
    local allyCount = 0
    local totalPower = 0

    for allyNumber, teams in pairs(playerAllies) do
        local allyPower = 0
        for id, _ in pairs (teams) do
            if playerTeams[id] then
                local power = teamPowers[id]
                allyPower = allyPower + power
            end
        end
        if allyPower > 0 then
            allyPowers[allyNumber] = allyPower
            allyCount = allyCount + 1
            totalPower = totalPower + allyPower
        end
    end

    local averagePower = allyCount > 0 and totalPower / allyCount or 0

    local ratio = averagePower > 0 and allyPowers[allyID] and allyPowers[allyID] / averagePower or 0
    return ratio
end

-- Returns boolean true if the input teamID's allies or allyID is considered significantly more powerful by the API. Third argument allows user-defined ratio.
local function isAllyTeamWinning(teamID, allyID, marginRatio)
    allyID = allyID or select(6, Spring.GetTeamInfo(teamID))
    marginRatio = marginRatio or alliesAreWinningRatio
    local allyPowers = {}
    local allyCount = 0
    local totalPower = 0

    for allyNumber, teams in pairs(playerAllies) do
        local allyPower = 0
        for id, _ in pairs (teams) do
            if playerTeams[id] then
                local power = teamPowers[id]
                allyPower = allyPower + power
            end
        end
        if allyPower > 0 then
            allyPowers[allyNumber] = allyPower
            allyCount = allyCount + 1
            totalPower = totalPower + allyPower
        end
    end

    local averagePower = allyCount > 0 and totalPower / allyCount or 0
    local ratio = averagePower > 0 and allyPowers[allyID] and allyPowers[allyID] / averagePower or 0
    if ratio > marginRatio then
        return true
    else
        return false
    end
end


function gadget:Initialize()
    GG.PowerLib = {}
    GG.PowerLib["ScavengerTeam"] = scavengerTeam
    GG.PowerLib["RaptorTeam"] = raptorTeam
    GG.PowerLib["AiTeams"] = aiTeams
    GG.PowerLib["NeutralTeam"] = neutralTeam
    GG.PowerLib["HumanTeams"] = humanTeams
    GG.PowerLib["PlayerTeams"] = playerTeams
    GG.PowerLib["TeamPowers"] = teamPowers
    GG.PowerLib["PeakTeamPowers"] = peakTeamPowers
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
    GG.PowerLib["TeamComparedToAveragedPlayers"] = teamComparedToAveragedPlayers
    GG.PowerLib["IsTeamOverPowered"] = isTeamOverPowered
    GG.PowerLib["AlliesComparedToAverage"] = alliesComparedToAverage
    GG.PowerLib["IsAllyTeamWinning"] = isAllyTeamWinning
end