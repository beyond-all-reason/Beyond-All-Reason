

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


--use VFS.Include("luarules/gadgets/game_team_power_watcher.lua") assuming filepath is still correct to gain access to the data within this gadget and use its functions
GG.PowerLib = {
    PowerThresholds = {
        {techLevel = 1, threshold = 9000},
        {techLevel = 1.5, threshold = 45000},
        {techLevel = 2, threshold = 90000},
        {techLevel = 2.5, threshold = 230000},
        {techLevel = 3, threshold = 350000},
        {techLevel = 3.5, threshold = 475000},
        {techLevel = 4, threshold = 600000},
        {techLevel = 4.5, threshold = 725000}
    },

    PeakTeamPowers = {},
    TeamPowers = {},
    UnitsWithPower = {},

    ScavengerTeam = nil,
    RaptorTeam = nil,
    NeutralTeam = nil,
    AITeams = {},
    HumanTeams = {}
}

local spGetGameSeconds = Spring.GetGameSeconds

local teamList = Spring.GetTeamList()

local testPowerTable = {}
local testPowerNumber = 0

--decipher human vs ai vs neutral vs defense mode ai's 
for _, teamID in ipairs(teamList) do
    local teamLuaAI = Spring.GetTeamLuaAI(teamID)
    if (teamLuaAI and string.find(teamLuaAI, "ScavengersAI")) then
        GG.PowerLib.ScavengerTeam = teamID
    elseif (teamLuaAI and string.find(teamLuaAI, "RaptorsAI")) then
        GG.PowerLib.RaptorTeam = teamID
    elseif select (4, Spring.GetTeamInfo(teamID, false)) then
        GG.PowerLib.AITeams[teamID] = true
    elseif teamID == tonumber(teamList[#teamList]) then
        GG.PowerLib.NeutralTeam = teamID
    else
        GG.PowerLib.HumanTeams[teamID] = true
    end
end

--assign all teams power and peak power of 0 to prevent nil errors
for _, teamNumber in ipairs(teamList) do
    GG.PowerLib.TeamPowers[teamNumber] = 0
    GG.PowerLib.PeakTeamPowers[teamNumber] = 0
end



function gadget:UnitFinished(unitID, unitDefID, unitTeam)
    GG.PowerLib.UnitsWithPower[unitID] = {unitID = unitID, power = UnitDefs[unitDefID].power, team = unitTeam}
    GG.PowerLib.TeamPowers[unitTeam] = (GG.PowerLib.TeamPowers[unitTeam] + UnitDefs[unitDefID].power) or UnitDefs[unitDefID].power
    
    --debug

    --testPowerTable = HighestAlliedPeakPower(unitTeam)
    --Spring.Echo(UnitDefs[unitDefID].name, unitTeam, UnitDefs[unitDefID].power, GG.PowerLib.TeamPowers[unitTeam], "test result", testPowerTable.teamID, testPowerTable.power)

    --testPowerNumber = TechGuesstimate(GG.PowerLib.TeamPowers[unitTeam])
    --Spring.Echo(UnitDefs[unitDefID].name, unitTeam, UnitDefs[unitDefID].power, GG.PowerLib.TeamPowers[unitTeam], "test result", testPowerNumber)

    --update peak powers
    if GG.PowerLib.TeamPowers[unitTeam] and GG.PowerLib.PeakTeamPowers[unitTeam] < GG.PowerLib.TeamPowers[unitTeam] then
        GG.PowerLib.PeakTeamPowers[unitTeam] = GG.PowerLib.TeamPowers[unitTeam]
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
    if GG.PowerLib.UnitsWithPower[unitID] then
        GG.PowerLib.UnitsWithPower[unitID] = nil
    end
    if UnitDefs[unitDefID].power then
        if GG.PowerLib.TeamPowers[unitTeam] then
            if GG.PowerLib.TeamPowers[unitTeam] <= UnitDefs[unitDefID].power then
                GG.PowerLib.TeamPowers[unitTeam] = 0
            else
                GG.PowerLib.TeamPowers[unitTeam] = GG.PowerLib.TeamPowers[unitTeam] - UnitDefs[unitDefID].power
            end
        end
    end
end

--returns the power of the input teamID as a number
function GG.PowerLib.TeamPower(teamID)
    for id, power in pairs(GG.PowerLib.TeamPowers) do
        if id == teamID then
            return power
        end
    end
    return 0
end

-- TotalTeamPower() returns the total power of all non scavenger/raptor teams as a number
function GG.PowerLib.TotalPlayerTeamsPower() 
    local totalPower = 0

    for teamID, power in pairs(GG.PowerLib.TeamPowers) do
        if teamID ~= GG.PowerLib.NeutralTeam and teamID ~= GG.PowerLib.ScavengerTeam and teamID ~= GG.PowerLib.RaptorTeam then
            totalPower = totalPower + power
        end
    end

    return totalPower
end

--HighestTeamPower() returns the highest non scavenger/raptor team power as a table {teamID, power}
function GG.PowerLib.HighestPlayerTeamPower()
    local highestPower = 0
    local highestTeamID = nil

    for teamID, power in pairs(GG.PowerLib.TeamPowers) do
        if teamID ~= GG.PowerLib.NeutralTeam and teamID ~= GG.PowerLib.ScavengerTeam and teamID ~= GG.PowerLib.RaptorTeam then
            if power > highestPower then
                highestPower = power
                highestTeamID = teamID
            end
        end
    end

    return {teamID = highestTeamID, power = highestPower}
end

--AverageTeamPower() returns the average of all non scavenger/raptor teams as a number
function GG.PowerLib.AveragePlayerTeamPower()
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(GG.PowerLib.TeamPowers) do
        if id ~= GG.PowerLib.NeutralTeam and id ~= GG.PowerLib.ScavengerTeam and id ~= GG.PowerLib.RaptorTeam then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = totalPower / teamCount
    return averagePower
end

--LowestTeamPower() returns the lowest non scavenger/raptor team power as a table {teamID, power}
function GG.PowerLib.LowestPlayerTeamPower()
    local lowestPower = math.huge
    local lowestTeamID = nil

    for teamID, power in pairs(GG.PowerLib.TeamPowers) do
        if teamID ~= GG.PowerLib.NeutralTeam and teamID ~= GG.PowerLib.ScavengerTeam and teamID ~= GG.PowerLib.RaptorTeam then
            if power < lowestPower then
                lowestPower = power
                lowestTeamID = teamID
            end
        end
    end

    return {teamID = lowestTeamID, power = lowestPower}
end


--HighestHumanTeamPower() returns the highest non AI/scavenger/raptor team power as a table {teamID, power}
function GG.PowerLib.HighestHumanTeamPower()
    local highestPower = 0
    local highestTeamID = nil

    for teamID, power in pairs(GG.PowerLib.TeamPowers) do
        if GG.PowerLib.HumanTeams[teamID] then
            if power > highestPower then
                highestPower = power
                highestTeamID = teamID
            end
        end
    end

    return {teamID = highestTeamID, power = highestPower}
end

--AverageHumanTeamPower() returns the average of all non AI/scavenger/raptor teams as a number
function GG.PowerLib.AverageHumanTeamPower()
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(GG.PowerLib.TeamPowers) do
        if GG.PowerLib.HumanTeams[id] then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = totalPower / teamCount
    return averagePower
end

--LowestTeamPower() returns the lowest non AI/scavenger/raptor team power as a table {teamID, power}
function GG.PowerLib.LowestHumanTeamPower()
    local lowestPower = math.huge
    local lowestTeamID = nil

    for teamID, power in pairs(GG.PowerLib.TeamPowers) do
        if GG.PowerLib.HumanTeams[teamID] then
            if power < lowestPower then
                lowestPower = power
                lowestTeamID = teamID
            end
        end
    end

    return {teamID = lowestTeamID, power = lowestPower}
end


--HighestAlliedTeamPower(teamID) returns the highest team power of the allies belonging to input team. Returns as a table {teamID, power}
function GG.PowerLib.HighestAlliedTeamPower(teamID)
    local allyTeamNum = select(6, Spring.GetTeamInfo(teamID))
    local highestPower = 0
    local highestTeamID = nil

    for id, power in pairs(GG.PowerLib.TeamPowers) do
        if allyTeamNum == select(6, Spring.GetTeamInfo(id)) then
            if power > highestPower then
                highestPower = power
                highestTeamID = id
            end
        end
    end

    return {teamID = highestTeamID, power = highestPower}
end

-- AverageAlliedTeamPower(teamID) returns the average of all allies of the input teamID. Returns a number.
function GG.PowerLib.AverageAlliedTeamPower(teamID) 
    local allyTeamNum = select(6, Spring.GetTeamInfo(teamID))
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(GG.PowerLib.TeamPowers) do
        if allyTeamNum == select(6, Spring.GetTeamInfo(id)) then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = totalPower / teamCount
    return averagePower
end

--LowestAlliedTeamPower(teamID) returns the lowest of the teamID's allies power as a table {teamID, power}
function GG.PowerLib.LowestAlliedTeamPower(teamID)
    local allyTeamNum = select(6, Spring.GetTeamInfo(teamID))
    local lowestPower = math.huge
    local lowestTeamID = nil

    for id, power in pairs(GG.PowerLib.TeamPowers) do
        if allyTeamNum == select(6, Spring.GetTeamInfo(id)) then
            if power < lowestPower then
                lowestPower = power
                lowestTeamID = id
            end
        end
    end

    return {teamID = lowestTeamID, power = lowestPower}
end


--TechGuesstimate(teamPower) takes an input of a power value and compares it against GG.PowerLib.PowerThresholds table and returns an estimated tech level from 0.5-4.5
function GG.PowerLib.TechGuesstimate(power)
    local techLevel = 0.5
    for _, threshold in ipairs(GG.PowerLib.PowerThresholds) do
        if power >= threshold.threshold then
            techLevel = threshold.techLevel
        else
            break
        end
    end

    return techLevel
end

--TeamTechGuesstimate(teamID) takes an input teamID and compares its power against GG.PowerLib.PowerThresholds table and returns an estimated tech level from 0.5-4.5
function GG.PowerLib.TeamTechGuesstimate(teamID)
    local totalPower = GG.PowerLib.TeamPowers[teamID]
    local techLevel = 0.5
    for _, threshold in ipairs(GG.PowerLib.PowerThresholds) do
        if totalPower >= threshold.threshold then
            techLevel = threshold.techLevel
        else
            break
        end
    end

    return techLevel
end

--AverageTechGuesstimate() compares average powers of all non scavenger/raptor teams against GG.PowerLib.PowerThresholds table and returns an estimated tech level from 0.5-4.5
function GG.PowerLib.AveragePlayerTechGuesstimate()
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(GG.PowerLib.TeamPowers) do
        if id ~= GG.PowerLib.NeutralTeam and id ~= GG.PowerLib.ScavengerTeam and id ~= GG.PowerLib.RaptorTeam then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = totalPower / teamCount

    local techLevel = 0.5
    for _, threshold in ipairs(GG.PowerLib.PowerThresholds) do
        if averagePower >= threshold.threshold then
            techLevel = threshold.techLevel
        else
            break
        end
    end

    return techLevel
end

--AverageHumanTechGuesstimate() compares average powers of all non AI/scavenger/raptor teams against GG.PowerLib.PowerThresholds table and returns an estimated tech level from 0.5-4.5
function GG.PowerLib.AverageHumanTechGuesstimate()
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(GG.PowerLib.TeamPowers) do
        if GG.PowerLib.HumanTeams[id] then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = totalPower / teamCount

    local techLevel = 0.5
    for _, threshold in ipairs(GG.PowerLib.PowerThresholds) do
        if averagePower >= threshold.threshold then
            techLevel = threshold.techLevel
        else
            break
        end
    end

    return techLevel
end

--AverageAlliedTechGuesstimate(teamID) compares average powers of all allied teams of the input teamID against GG.PowerLib.PowerThresholds table and returns an estimated tech level from 0.5-4.5
function GG.PowerLib.AverageAlliedTechGuesstimate(teamID)
    local allyTeamNum = select(6, Spring.GetTeamInfo(teamID))
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(GG.PowerLib.TeamPowers) do
        if allyTeamNum == select(6, Spring.GetTeamInfo(id)) then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = totalPower / teamCount

    local techLevel = 0.5
    for _, threshold in ipairs(GG.PowerLib.PowerThresholds) do
        if averagePower >= threshold.threshold then
            techLevel = threshold.techLevel
        else
            break
        end
    end

    return techLevel
end


--TeamPeakPower(teamID) returns the highest power achieved by the the input teamID as a number.
function GG.PowerLib.TeamPeakPower(teamID)
    for id, power in pairs(GG.PowerLib.PeakTeamPowers) do
        if id == teamID then
            return power
        end
    end
    return 0
end

-- TotalPeakPower() returns the total peak power achieved by all non scavenger/raptor teams as a number
function GG.PowerLib.TotalPlayerPeakPower()
    local totalPeakPower = 0

    for id, power in pairs(GG.PowerLib.PeakTeamPowers) do
        if id ~= GG.PowerLib.NeutralTeam and id ~= GG.PowerLib.ScavengerTeam and id ~= GG.PowerLib.RaptorTeam then
            totalPeakPower = totalPeakPower + power
        end
    end

    return totalPeakPower
end

--HighestPeakPower() returns the highest power achieved by any non scavenger/raptor team as a table {teamID, power}
function GG.PowerLib.HighestPlayerPeakPower() 
    local highestPower = 0
    local highestTeamID = nil

    for id, power in pairs(GG.PowerLib.PeakTeamPowers) do
        if id ~= GG.PowerLib.NeutralTeam and id ~= GG.PowerLib.ScavengerTeam and id ~= GG.PowerLib.RaptorTeam then
            if power > highestPower then
                highestPower = power
                highestTeamID = id
            end
        end
    end

    return {teamID = highestTeamID, power = highestPower}
end

--HighestAlliedPeakPower(teamID) returns the highest power achieved by any non scavenger/raptor team on the same team as the input teamID as a table {teamID, power}
function GG.PowerLib.HighestAlliedPeakPower(teamID) 
    local allyTeamNum = select(6, Spring.GetTeamInfo(teamID))
    local highestPower = 0
    local highestTeamID = nil

    for id, power in pairs(GG.PowerLib.PeakTeamPowers) do
        if allyTeamNum == select(6, Spring.GetTeamInfo(id)) then
            if power > highestPower then
                highestPower = power
                highestTeamID = id
            end
        end
    end

    return {teamID = highestTeamID, power = highestPower}
end

--AverageHumanPeakPower() returns the average of all the peak powers achieved by non AI/scavenger/raptor teams as a number
function GG.PowerLib.AverageHumanPeakPower()
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(GG.PowerLib.PeakTeamPowers) do
        if GG.PowerLib.HumanTeams[id] then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = totalPower / teamCount
    return averagePower
end

--AverageAlliedPeakPower(teamID) returns the average of all the peak powers achieved by allied teams of the input teamID as a number.
function GG.PowerLib.AverageAlliedPeakPower(teamID)  
    local allyTeamNum = select(6, Spring.GetTeamInfo(teamID))
    local totalPower = 0
    local teamCount = 0

    for id, power in pairs(GG.PowerLib.PeakTeamPowers) do
        if allyTeamNum == select(6, Spring.GetTeamInfo(id)) then
            totalPower = totalPower + power
            teamCount = teamCount + 1
        end
    end

    local averagePower = totalPower / teamCount
    return averagePower
end