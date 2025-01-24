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

if not gadgetHandler:IsSyncedCode() then --synced only
	return false
end

local teamComs = {} -- format is enemyComs[teamID] = total # of coms in enemy teams
local countChanged  = true

local alliedTeamCombo = {}
local teamList = Spring.GetTeamList()
for _, teamID in ipairs(teamList) do
	for _, otherTeamID in ipairs(teamList) do
		if select(6,Spring.GetTeamInfo(otherTeamID,false)) ~= select(6,Spring.GetTeamInfo(teamID,false)) then
			alliedTeamCombo[teamID..'_'..otherTeamID] = true
		end
	end
end


local isCommander = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.iscommander or unitDef.customParams.isscavcommander then
		isCommander[unitDefID] = true
	end
end


function gadget:UnitCreated(unitID, unitDefID, teamID)
	if isCommander[unitDefID] then
		if not teamComs[teamID] then
			teamComs[teamID] = 0
		end
		teamComs[teamID] = teamComs[teamID] + 1
		countChanged = true
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID)
	if isCommander[unitDefID] then
		if not teamComs[teamID] then
			teamComs[teamID] = 0 --should never happen
		end
		teamComs[teamID] = teamComs[teamID] - 1
		countChanged = true
	end
end


-- BAR does not allow sharing to enemy, thus no need to check Given, Taken units


function gadget:GameFrame(n)
	if countChanged then
		UpdateCount()
		countChanged = false
	end
end

function UpdateCount()
	for teamID,_ in pairs(teamComs) do
		-- count all coms in enemy teams, to get enemy allyteam com count
		local enemyComCount = 0
		for otherTeamID,_ in pairs(teamComs) do
			if alliedTeamCombo[teamID..'_'..otherTeamID] then
				enemyComCount = enemyComCount + teamComs[otherTeamID]
			end
		end
		-- for each teamID, set a TeamRulesParam containing the # of coms in enemy allyteams
		Spring.SetTeamRulesParam(teamID, "enemyComCount", enemyComCount, {private=true, allied=false})
	end
end
