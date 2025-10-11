local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unit Limit Enforcer",
		desc = "Prevents exceeding maxthisunit limits by blocking excess build commands.",
		author = "timuela",
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
local teamQueuedCounts = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.maxThisUnit and unitDef.maxThisUnit > 0 and unitDef.maxThisUnit < 10000 then
		limitedUnits[unitDefID] = unitDef.maxThisUnit
	end
end

local function getQueuedCount(teamID, unitDefID)
	return teamQueuedCounts[teamID] and teamQueuedCounts[teamID][unitDefID] or 0
end

local function addQueuedCount(teamID, unitDefID)
	teamQueuedCounts[teamID] = teamQueuedCounts[teamID] or {}
	teamQueuedCounts[teamID][unitDefID] = getQueuedCount(teamID, unitDefID) + 1
end

local function removeQueuedCount(teamID, unitDefID)
	if not teamQueuedCounts[teamID] or not teamQueuedCounts[teamID][unitDefID] then
		return
	end

	teamQueuedCounts[teamID][unitDefID] = teamQueuedCounts[teamID][unitDefID] - 1
	if teamQueuedCounts[teamID][unitDefID] <= 0 then
		teamQueuedCounts[teamID][unitDefID] = nil
	end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID)
	if cmdID < 0 then
		local buildUnitDefID = -cmdID
		if limitedUnits[buildUnitDefID] then
			local existingCount = 0
			for _, uid in ipairs(Spring.GetTeamUnits(unitTeam)) do
				if Spring.GetUnitDefID(uid) == buildUnitDefID then
					existingCount = existingCount + 1
				end
			end
			local queuedCount = getQueuedCount(unitTeam, buildUnitDefID)
			if (existingCount + queuedCount) >= limitedUnits[buildUnitDefID] then
				return false
			end
			addQueuedCount(unitTeam, buildUnitDefID)
		end
	end
	return true
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if limitedUnits[unitDefID] then
		removeQueuedCount(unitTeam, unitDefID)
	end
end
