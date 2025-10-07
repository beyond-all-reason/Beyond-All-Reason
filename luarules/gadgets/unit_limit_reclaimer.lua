local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unit Limit Enforcer",
		desc = "Enforces maxthisunit limits by instantly reclaiming excess units and refunding metal.",
		author = "Timuela",
		date = "October 2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local limitedUnits = {}
local teamCounts = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.maxThisUnit and unitDef.maxThisUnit > 0 and unitDef.maxThisUnit < 10000 then
		limitedUnits[unitDefID] = { max = unitDef.maxThisUnit, cost = unitDef.metalCost }
	end
end

local function addUnit(teamID, unitDefID, unitID)
	teamCounts[teamID] = teamCounts[teamID] or {}
	teamCounts[teamID][unitDefID] = teamCounts[teamID][unitDefID] or {}
	table.insert(teamCounts[teamID][unitDefID], unitID)
end

local function removeUnit(teamID, unitDefID, unitID)
	if teamCounts[teamID] and teamCounts[teamID][unitDefID] then
		for i, id in ipairs(teamCounts[teamID][unitDefID]) do
			if id == unitID then
				table.remove(teamCounts[teamID][unitDefID], i)
				break
			end
		end
	end
end

local function enforceLimit(teamID, unitDefID, newUnitID)
	local units = teamCounts[teamID][unitDefID]
	local limit = limitedUnits[unitDefID]

	while #units > limit.max do
		local oldestID = nil
		for _, unitID in ipairs(units) do
			if unitID ~= newUnitID and Spring.ValidUnitID(unitID) then
				oldestID = unitID
				break
			end
		end

		if oldestID then
			Spring.DestroyUnit(oldestID, false, true)
			Spring.AddTeamResource(teamID, "metal", limit.cost)
			removeUnit(teamID, unitDefID, oldestID)
		else
			break
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if limitedUnits[unitDefID] then
		addUnit(unitTeam, unitDefID, unitID)
		enforceLimit(unitTeam, unitDefID, unitID)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if limitedUnits[unitDefID] then
		removeUnit(unitTeam, unitDefID, unitID)
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if limitedUnits[unitDefID] then
		removeUnit(oldTeam, unitDefID, unitID)
		addUnit(newTeam, unitDefID, unitID)
		enforceLimit(newTeam, unitDefID, unitID)
	end
end

function gadget:Initialize()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		if limitedUnits[unitDefID] then
			addUnit(Spring.GetUnitTeam(unitID), unitDefID, unitID)
		end
	end

	for teamID, teamData in pairs(teamCounts) do
		for unitDefID, units in pairs(teamData) do
			enforceLimit(teamID, unitDefID, nil)
		end
	end
end
