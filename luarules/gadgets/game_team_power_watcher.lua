

function gadget:GetInfo()
	return {
		name = "Team Power Watcher",
		desc = "Tracks power of individual and total units per team. To be used for PvE dynamic difficulty and library functions to assertain game progression",
		author = "SethDGamre",
		date = "2024-07-12",
		license = "None",
		layer = 1,
		enabled = true
	}
end

if gadgetHandler:IsSyncedCode() then

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
	local teamPowerList = {}
	local highestTeamPower = {}
    local averageTeamPower = 0
    local averageAlliedTeamPower = 0

    --AI team lists
    local scavTeam
    local raptorTeam
    local AIteams = {}
    local humanTeams = {}


--get AI teams
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

--assign all teams power of 0 to prevent nil errors
    for _, teamNumber in ipairs(teamList) do
        teamPowerList[teamNumber] = 0
    end


	function gadget:UnitFinished(unitID, unitDefID, unitTeam)
		if UnitDefs[unitDefID].power then
            unitsWithPower[unitID] = {unitID = unitID, power = UnitDefs[unitDefID].power, team = unitTeam}
            teamPowerList[unitTeam] = (teamPowerList[unitTeam] + UnitDefs[unitDefID].power) or UnitDefs[unitDefID].power
            highestTeamPower = TPW_HighestTeamPower()
            averageTeamPower = TPW_AverageTeamPower()
            averageAlliedTeamPower = TPW_AverageAlliedTeamPower(unitTeam)

           -- Spring.Echo(UnitDefs[unitDefID].name, unitTeam, UnitDefs[unitDefID].power, teamPowerList[unitTeam], "highest", highestTeamPower.teamID, highestTeamPower.power)
           Spring.Echo(UnitDefs[unitDefID].name, unitTeam, UnitDefs[unitDefID].power, teamPowerList[unitTeam], "averageTeamPower", averageTeamPower)
           Spring.Echo(UnitDefs[unitDefID].name, unitTeam, UnitDefs[unitDefID].power, teamPowerList[unitTeam], "averageAlliedTeamPower", averageAlliedTeamPower)
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
        if unitsWithPower[unitID] then
			unitsWithPower[unitID] = nil
		end
        if UnitDefs[unitDefID].power then
            if teamPowerList[unitTeam] then
                if teamPowerList[unitTeam] <= UnitDefs[unitDefID].power then
                    teamPowerList[unitTeam] = 0
                else
                    teamPowerList[unitTeam] = teamPowerList[unitTeam] - UnitDefs[unitDefID].power
                end
            end
            --Spring.Echo(UnitDefs[unitDefID].name, unitTeam, UnitDefs[unitDefID].power, teamPowerList[unitTeam])
        end
	end

    function TPW_HighestTeamPower()
        local power = 0
        local teamID = nil
    
        for t, p in pairs(teamPowerList) do
            if p > power then
                power = p
                teamID = t
            end
        end
    
        return {teamID = teamID, power = power}
    end


    function TPW_AverageTeamPower()
        local totalPower = 0
        local teamCount = 0
    
        for _, p in pairs(teamPowerList) do
            if id ~= neutralTeamNumber then
                totalPower = totalPower + p
                teamCount = teamCount + 1
            end
        end
    
        local averagePower = totalPower / teamCount
        return averagePower
    end


    function TPW_AverageAlliedTeamPower(teamID)
        local allyTeamNum = select(6, Spring.GetTeamInfo(teamID))
        local totalPower = 0
        local teamCount = 0
    
        for id, p in pairs(teamPowerList) do
            if allyTeamNum == select(6, Spring.GetTeamInfo(id)) then
                totalPower = totalPower + p
                teamCount = teamCount + 1
            end
        end
    
        local averagePower = totalPower / teamCount
        return averagePower
    end

    --function TPW_AverageTechGuesstimate()
    --end
end