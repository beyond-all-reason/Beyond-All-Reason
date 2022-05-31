function gadget:GetInfo()
	return {
		name      = "Com Counter",
		desc      = "Tells each team the total number of commanders alive in enemy allyteams",
		author    = "Bluestone",
		date      = "08/03/2014",
		license   = "Horses",
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end

-------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------

if not (gadgetHandler:IsSyncedCode()) then --synced only
	return false
end

local teamComs = {} -- format is enemyComs[teamID] = total # of coms in enemy teams
local armcomDefID = UnitDefNames.armcom.id
local corcomDefID = UnitDefNames.corcom.id
local legcomDefID = UnitDefNames.legcomdef.id
local countChanged  = true

local isCommander = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.iscommander then
		isCommander[unitDefID] = true
	end
end


function gadget:UnitCreated(unitID, unitDefID, teamID)
	-- record com creation
	if isCommander[unitDefID] then
		if not teamComs[teamID] then
			teamComs[teamID] = 0
		end
		teamComs[teamID] = teamComs[teamID] + 1
		countChanged = true
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID)
	-- record com death
	if isCommander[unitDefID] then
		if not teamComs[teamID] then
			teamComs[teamID] = 0 --should never happen
		end
		teamComs[teamID] = teamComs[teamID] - 1
		countChanged = true
	end
end

-- BAR does not allow sharing to enemy, so no need to check Given, Taken, etc

local function ReCheck()
	-- occasionally, recheck just to make sure...
	local teamList = Spring.GetTeamList()
	for _,teamID in pairs(teamList) do
		local newCount = Spring.GetTeamUnitDefCount(teamID, armcomDefID) + Spring.GetTeamUnitDefCount(teamID, corcomDefID) + Spring.GetTeamUnitDefCount(teamID, legcomDefID)
		if newCount ~= teamComs[teamID] then
			countChanged = true
			teamComs[teamID] = newCount
		end
	end
end

function gadget:GameFrame(n)
	if n%30==0 then
		ReCheck()
	end

	if countChanged then
		UpdateCount()
		countChanged = false
	end
end

function UpdateCount()
	-- for each teamID, set a TeamRulesParam containing the # of coms in enemy allyteams
	for teamID,_ in pairs(teamComs) do
		local enemyComCount = 0
		for otherTeamID,val in pairs(teamComs) do -- count all coms in enemy teams, to get enemy allyteam com count
			if select(6,Spring.GetTeamInfo(otherTeamID,false)) ~= select(6,Spring.GetTeamInfo(teamID,false)) then
				enemyComCount = enemyComCount + teamComs[otherTeamID]
			end
		end
		--Spring.Echo(teamID, teamComs[teamID], enemyComCount)
		Spring.SetTeamRulesParam(teamID, "enemyComCount", enemyComCount, {private=true, allied=false})
	end
end
