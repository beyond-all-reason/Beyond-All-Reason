function widget:GetInfo()
	return {
		name    = "Clean Builder Queue",
		desc    = "Removes completed buildings from all builders unit queue in case they werent there completing it (unless they have repeat enabled)",
		author  = "Floris",
		date    = "May 2025",
		license = "GNU GPL v2",
		layer   = 0,
		enabled = true,
	}
end

local GetUnitCmdDescs    = Spring.GetUnitCmdDescs
local GetUnitCommands    = Spring.GetUnitCommands
local GiveOrderToUnit    = Spring.GiveOrderToUnit
local GetUnitPosition    = Spring.GetUnitPosition
local GetUnitDefID       = Spring.GetUnitDefID
local GetTeamUnits       = Spring.GetTeamUnits
local GetMyTeamID        = Spring.GetMyTeamID
local GetSpectatingState = Spring.GetSpectatingState
local GetUnitsInCylinder = Spring.GetUnitsInCylinder

local CMD_REMOVE         = CMD.REMOVE
local CMD_REPEAT         = CMD.REPEAT

local REMOVE_TOLERANCE   = 5 * 5 -- squared distance

local trackedBuilders    = {}
local isBuilding         = {}
local builderDefs        = {}
local myTeamID           = GetMyTeamID()

-- Calculate maximum build distance from all builder units + margin
local maxBuildDistance   = 0
for udid, ud in pairs(UnitDefs) do
	if ud.isBuilder and ud.buildDistance then
		maxBuildDistance = math.max(maxBuildDistance, ud.buildDistance)
	end
end
local SEARCH_RADIUS      = maxBuildDistance + 200  -- Max build distance + safety margin

-- Cache repeat status to avoid repeated cmdDescs lookups
local repeatStatus       = {}
-- Reusable table for nearby builders to reduce allocations
local nearbyBuilders     = {}

local function IsUnitRepeatOn(unitID)
	if repeatStatus[unitID] ~= nil then
		return repeatStatus[unitID]
	end

	local cmdDescs = GetUnitCmdDescs(unitID)
	if not cmdDescs then
		repeatStatus[unitID] = false
		return false
	end
	for _, desc in ipairs(cmdDescs) do
		if desc.id == CMD_REPEAT then
			local isOn = desc.params and desc.params[1] == "1"
			repeatStatus[unitID] = isOn
			return isOn
		end
	end
	repeatStatus[unitID] = false
	return false
end

local function coordsMatch(x1, z1, x2, z2, tolerance)
	local dx = x1 - x2
	local dz = z1 - z2
	return dx * dx + dz * dz <= tolerance
end

function widget:Initialize()
	if GetSpectatingState() then
		widgetHandler:RemoveWidget(self)
		return
	end

	for udid, ud in pairs(UnitDefs) do
		if ud.isBuilder then
			builderDefs[udid] = true
		end
		if ud.isBuilding or ud.speed == 0 then
			isBuilding[udid] = true
		end
	end

	local allUnits = GetTeamUnits(myTeamID)
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		if builderDefs[GetUnitDefID(unitID)] then
			trackedBuilders[unitID] = true
		end
	end
end

function widget:PlayerChanged(playerID)
	if GetSpectatingState() then
		widgetHandler:RemoveWidget(self)
		return
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if unitTeam == myTeamID and builderDefs[unitDefID] then
		trackedBuilders[unitID] = true
		repeatStatus[unitID] = nil
	end
end

function widget:UnitDestroyed(unitID)
	trackedBuilders[unitID] = nil
	repeatStatus[unitID] = nil
end

function widget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID)
	-- Invalidate repeat cache when command changes
	if trackedBuilders[unitID] and cmdID == CMD_REPEAT then
		repeatStatus[unitID] = nil
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam ~= myTeamID or not isBuilding[unitDefID] then
		return
	end

	local x, _, z = GetUnitPosition(unitID)
	if not x then return end

	-- Use spatial query to only check nearby units instead of all builders
	local nearbyUnits = GetUnitsInCylinder(x, z, SEARCH_RADIUS)
	if not nearbyUnits or #nearbyUnits == 0 then return end

	-- Clear and reuse nearbyBuilders table to reduce allocations
	local builderCount = 0
	for i = 1, #nearbyUnits do
		local nearbyID = nearbyUnits[i]
		if trackedBuilders[nearbyID] then
			builderCount = builderCount + 1
			nearbyBuilders[builderCount] = nearbyID
		end
	end

	if builderCount == 0 then return end

	local targetCmdID = -unitDefID

	-- Process only nearby builders
	for i = 1, builderCount do
		local builderID = nearbyBuilders[i]

		-- Skip if repeat is enabled (cached check)
		if not IsUnitRepeatOn(builderID) then
			local commands = GetUnitCommands(builderID, 32)
			if commands then
				-- Scan backwards to find matching build commands
				for j = #commands, 1, -1 do
					local cmd = commands[j]
					-- Only check build commands for this specific unitDefID
					if cmd.id == targetCmdID then
						local params = cmd.params
						if params and params[1] and params[3] then
							if coordsMatch(x, z, params[1], params[3], REMOVE_TOLERANCE) then
								GiveOrderToUnit(builderID, CMD_REMOVE, { cmd.tag }, {})
								break -- Only remove first matching command per builder
							end
						end
					end
				end
			end
		end
	end

	-- Clear table for next use
	for i = 1, builderCount do
		nearbyBuilders[i] = nil
	end
end
