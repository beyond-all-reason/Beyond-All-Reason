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
local teamLivingCounts = {}
local shouldRemoveGadget = true

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.maxThisUnit and unitDef.maxThisUnit > 0 and unitDef.maxThisUnit < 10000 then
		limitedUnits[unitDefID] = unitDef.maxThisUnit
		shouldRemoveGadget = false
	end
end

if shouldRemoveGadget then
	gadgetHandler:RemoveGadget(gadget)
	return
end

local function getQueuedCount(teamID, unitDefID)
	return teamQueuedCounts[teamID] and teamQueuedCounts[teamID][unitDefID] or 0
end

local function getLivingCount(teamID, unitDefID)
	return teamLivingCounts[teamID] and teamLivingCounts[teamID][unitDefID] or 0
end

local function ensureTeamCountsTable(teamID)
	teamQueuedCounts[teamID] = teamQueuedCounts[teamID] or {}
end

local function decrementQueuedCount(teamID, unitDefID)
	ensureTeamCountsTable(teamID)
	local currentCount = getQueuedCount(teamID, unitDefID)
	if currentCount > 0 then
		teamQueuedCounts[teamID][unitDefID] = currentCount - 1
	end
end

local function isUnitLimited(unitDefID)
	return limitedUnits[unitDefID] ~= nil
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions)
	if cmdID >= 0 then
		return true
	end
	local buildUnitDefID = -cmdID
	if not isUnitLimited(buildUnitDefID) then
		return true
	end

	local isCancelCommand = cmdOptions.right and cmdOptions.coded == 16
	local isBuildCommand = not cmdOptions.right

	if isCancelCommand then
		decrementQueuedCount(unitTeam, buildUnitDefID)
		return true
	elseif isBuildCommand then
		local livingCount = getLivingCount(unitTeam, buildUnitDefID)
		local queuedCount = getQueuedCount(unitTeam, buildUnitDefID)
		local totalCount = livingCount + queuedCount
		local maxAllowed = limitedUnits[buildUnitDefID]

		if totalCount >= maxAllowed then
			return false
		end
		ensureTeamCountsTable(unitTeam)
		local currentCount = getQueuedCount(unitTeam, buildUnitDefID)
		teamQueuedCounts[unitTeam][buildUnitDefID] = currentCount + 1
		return true
	end

	return true
end

function gadget:MetaUnitAdded(unitID, unitDefID, unitTeam)
	if isUnitLimited(unitDefID) then
		teamLivingCounts[unitTeam] = teamLivingCounts[unitTeam] or {}
		local currentCount = getLivingCount(unitTeam, unitDefID)
		teamLivingCounts[unitTeam][unitDefID] = currentCount + 1
	end
end

function gadget:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	if isUnitLimited(unitDefID) then
		if teamLivingCounts[unitTeam] and teamLivingCounts[unitTeam][unitDefID] then
			local currentCount = teamLivingCounts[unitTeam][unitDefID]
			teamLivingCounts[unitTeam][unitDefID] = math.max(currentCount - 1, 0)
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if isUnitLimited(unitDefID) then
		decrementQueuedCount(unitTeam, unitDefID)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if isUnitLimited(unitDefID) then
		local _, _, inBuild = Spring.GetUnitIsStunned(unitID)
		if inBuild then
			decrementQueuedCount(unitTeam, unitDefID)
		end
	end
end
