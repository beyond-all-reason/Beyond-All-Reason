function widget:GetInfo()
	return {
		name = "Clean Builder Queue",
		desc = "Removes completed buildings from all builders unit queue in case they werent there completing it (unless they have repeat enabled)",
		author = "Floris",
		date = "May 2025",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true,
	}
end

local GetUnitCommands = SpringShared.GetUnitCommands
local GetUnitCommandCount = SpringShared.GetUnitCommandCount
local GetUnitStates = SpringShared.GetUnitStates
local GiveOrderToUnit = SpringShared.GiveOrderToUnit
local GetUnitPosition = SpringShared.GetUnitPosition
local GetUnitDefID = SpringShared.GetUnitDefID
local GetTeamUnits = SpringShared.GetTeamUnits
local GetMyTeamID = SpringUnsynced.GetLocalTeamID
local GetSpectatingState = SpringUnsynced.GetSpectatingState
local GetUnitsInCylinder = SpringShared.GetUnitsInCylinder
local select = select

local CMD_REMOVE = CMD.REMOVE
local CMD_REPEAT = CMD.REPEAT

local REMOVE_TOLERANCE = 5 * 5 -- squared distance

local trackedBuilders = {}
local isBuilding = {}
local builderDefs = {}
local myTeamID = GetMyTeamID()

-- Calculate maximum build distance from all builder units + margin
local maxBuildDistance = 0
for udid, ud in pairs(UnitDefs) do
	if ud.isBuilder and ud.buildDistance then
		maxBuildDistance = math.max(maxBuildDistance, ud.buildDistance)
	end
end
local SEARCH_RADIUS = maxBuildDistance + 200 -- Max build distance + safety margin

-- Cache repeat status to avoid repeated lookups
local repeatStatus = {}
-- Reusable table for nearby builders to reduce allocations
local nearbyBuilders = {}

local function IsUnitRepeatOn(unitID)
	if repeatStatus[unitID] ~= nil then
		return repeatStatus[unitID]
	end
	-- GetUnitStates(id, false, true) returns individual values (no table alloc)
	-- 4th return value is repeat state (0 = off, 1 = on)
	local repeatState = select(4, GetUnitStates(unitID, false, true))
	local isOn = repeatState == 1
	repeatStatus[unitID] = isOn
	return isOn
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
	if not x then
		return
	end

	-- Use spatial query to only check nearby units (team-filtered to reduce table size)
	local nearbyUnits = GetUnitsInCylinder(x, z, SEARCH_RADIUS, myTeamID)
	if not nearbyUnits or #nearbyUnits == 0 then
		return
	end

	-- Clear and reuse nearbyBuilders table to reduce allocations
	local builderCount = 0
	for i = 1, #nearbyUnits do
		local nearbyID = nearbyUnits[i]
		if trackedBuilders[nearbyID] then
			builderCount = builderCount + 1
			nearbyBuilders[builderCount] = nearbyID
		end
	end

	if builderCount == 0 then
		return
	end

	local targetCmdID = -unitDefID

	-- Queue sharing: when builders were selected together, they have identical queues.
	-- After scanning the first builder, we know if a match exists and at which index.
	-- For subsequent builders with the same queue, we can either:
	--   - Skip entirely if no match was found (saves full GetUnitCommands + scan)
	--   - Fetch only up to the known match index to get the per-unit tag
	local sharedCmdCount -- command count of the first-scanned builder
	local sharedMatchIndex -- index of the matching command (nil = no match found)
	local sharedFirstCmdId -- first command id of the shared queue (for identity check)

	for i = 1, builderCount do
		local builderID = nearbyBuilders[i]

		-- Skip if repeat is enabled (cached check)
		if not IsUnitRepeatOn(builderID) then
			local cmdCount = GetUnitCommandCount(builderID)
			if cmdCount and cmdCount > 0 then
				-- Try to reuse shared scan result
				local didShare = false
				if sharedCmdCount and cmdCount == sharedCmdCount then
					-- Cheap probe: verify queue identity via first command
					local probe = GetUnitCommands(builderID, 1)
					if probe and probe[1] and probe[1].id == sharedFirstCmdId then
						didShare = true
						if sharedMatchIndex then
							-- We know a match exists at this index — fetch just enough
							local commands = GetUnitCommands(builderID, sharedMatchIndex)
							if commands and commands[sharedMatchIndex] then
								local cmd = commands[sharedMatchIndex]
								-- Verify id AND coords: the cheap first-command "probe" can
								-- collide between different queues that merely share their
								-- first cmd id. Removing without re-checking coords here
								-- would drop the wrong queued build from this builder.
								if cmd.id == targetCmdID then
									local params = cmd.params
									if params and params[1] and params[3] and coordsMatch(x, z, params[1], params[3], REMOVE_TOLERANCE) then
										GiveOrderToUnit(builderID, CMD_REMOVE, { cmd.tag }, {})
									else
										-- Probe matched first cmd by id only; queue is
										-- actually different. Fall back to a full scan
										-- so we don't miss the real match (or wrongly
										-- remove an unrelated command).
										didShare = false
									end
								else
									-- Same as above: shared assumption was wrong.
									didShare = false
								end
							end
						end
						-- else: no match in shared queue, skip this builder entirely
					end
				end

				if not didShare then
					-- Full fetch + scan path (first builder, or different queue)
					local limit = cmdCount < 32 and cmdCount or 32
					local commands = GetUnitCommands(builderID, limit)
					if commands then
						local matchIdx = nil
						for j = #commands, 1, -1 do
							local cmd = commands[j]
							if cmd.id == targetCmdID then
								local params = cmd.params
								if params and params[1] and params[3] then
									if coordsMatch(x, z, params[1], params[3], REMOVE_TOLERANCE) then
										GiveOrderToUnit(builderID, CMD_REMOVE, { cmd.tag }, {})
										matchIdx = j
										break
									end
								end
							end
						end

						-- Cache scan result for subsequent builders
						if not sharedCmdCount then
							sharedCmdCount = cmdCount
							sharedMatchIndex = matchIdx
							sharedFirstCmdId = commands[1] and commands[1].id or nil
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
