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
local unitBuildQueue = {}
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
	return Spring.GetTeamUnitDefCount(teamID, unitDefID) or 0
end

local function decrementQueuedCount(teamID, unitDefID)
	teamQueuedCounts[teamID] = teamQueuedCounts[teamID] or {}
	local currentCount = getQueuedCount(teamID, unitDefID)
	if currentCount > 0 then
		teamQueuedCounts[teamID][unitDefID] = currentCount - 1
	end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions)
	if cmdID >= 0 then
		if unitBuildQueue[unitID] then
			local interruptingCommands = {
				[CMD.MOVE] = true,
				[CMD.ATTACK] = true,
				[CMD.PATROL] = true,
				[CMD.FIGHT] = true,
				[CMD.GUARD] = true,
				[CMD.STOP] = true,
			}

			if interruptingCommands[cmdID] then
				for buildUnitDefID, queueCount in pairs(unitBuildQueue[unitID]) do
					for i = 1, queueCount do
						decrementQueuedCount(unitTeam, buildUnitDefID)
					end
				end
				unitBuildQueue[unitID] = nil
			end
		end
		return true
	end
	local buildUnitDefID = -cmdID
	if not limitedUnits[buildUnitDefID] then
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
		teamQueuedCounts[unitTeam] = teamQueuedCounts[unitTeam] or {}
		local currentCount = getQueuedCount(unitTeam, buildUnitDefID)
		teamQueuedCounts[unitTeam][buildUnitDefID] = currentCount + 1

		unitBuildQueue[unitID] = unitBuildQueue[unitID] or {}
		unitBuildQueue[unitID][buildUnitDefID] = (unitBuildQueue[unitID][buildUnitDefID] or 0) + 1
		return true
	end

	return true
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	unitBuildQueue[unitID] = nil
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if limitedUnits[unitDefID] then
		local _, _, inBuild = Spring.GetUnitIsStunned(unitID)
		if inBuild then
			decrementQueuedCount(unitTeam, unitDefID)
		end
	end
	unitBuildQueue[unitID] = nil
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if limitedUnits[unitDefID] then
		decrementQueuedCount(unitTeam, unitDefID)

		for builderID, buildQueue in pairs(unitBuildQueue) do
			if buildQueue[unitDefID] and buildQueue[unitDefID] > 0 then
				buildQueue[unitDefID] = buildQueue[unitDefID] - 1
				if buildQueue[unitDefID] == 0 then
					buildQueue[unitDefID] = nil
				end
				if next(buildQueue) == nil then
					unitBuildQueue[builderID] = nil
				end
				break
			end
		end
	end
end
