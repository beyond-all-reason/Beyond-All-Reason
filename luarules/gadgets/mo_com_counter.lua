local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Com Counter",
		desc      = "Tells each team the total number of commanders alive in enemy allyteams",
		author    = "Bluestone",
		date      = "08/03/2014",
		license   = "GNU GPL, v2 or later, Horses",
		layer     = 0,
		enabled   = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local spSetTeamRulesParam = Spring.SetTeamRulesParam

local isCommander = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.iscommander or unitDef.customParams.isscavcommander then
		isCommander[unitDefID] = true
	end
end

local teamComs = {}
local teamAllyTeam = {}
local teamList = Spring.GetTeamList()
for _,teamID in pairs(teamList) do
	teamAllyTeam[teamID] = select(6,Spring.GetTeamInfo(teamID,false))
	local newCount = 0
	for unitDefID,_ in pairs(isCommander) do
		newCount = newCount + Spring.GetTeamUnitDefCount(teamID, unitDefID)
	end
	teamComs[teamID] = newCount
end
teamList = nil

local function updateEnemyComCount()
	for teamID,_ in pairs(teamComs) do
		-- count all coms in enemy teams, to get enemy allyteam com count
		local enemyComCount = 0
		for otherTeamID,_ in pairs(teamComs) do
			if teamAllyTeam[teamID] ~= teamAllyTeam[otherTeamID] then
				enemyComCount = enemyComCount + teamComs[otherTeamID]
			end
		end
		-- for each teamID, set a TeamRulesParam containing the # of coms in enemy allyteams
		spSetTeamRulesParam(teamID, "enemyComCount", enemyComCount, {private=true, allied=false})
	end
end

function gadget:UnitCreated(unitID, unitDefID, teamID)
	if isCommander[unitDefID] then
		teamComs[teamID] = teamComs[teamID] + 1
		updateEnemyComCount()
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID)
	if isCommander[unitDefID] then
		teamComs[teamID] = teamComs[teamID] - 1
		updateEnemyComCount()
	end
end

function gadget:UnitTaken(unitID, unitDefID, teamID, newTeamID)
	if isCommander[unitDefID] then
		teamComs[teamID] = teamComs[teamID] - 1
		teamComs[newTeamID] = teamComs[newTeamID] + 1
		updateEnemyComCount()
	end
end
