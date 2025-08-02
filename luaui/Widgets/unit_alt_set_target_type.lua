local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name 	= "Set unit type target",
		desc 	= "Hold down Alt and set target on an enemy unit to automatically set target on all future enemies of that type",
		author  = "Flameink",
		date	= "August 1, 2025",
		version = "1.0",
		license = "GNU GPL, v2 or later",
		layer 	= 0,
		enabled = true
	}
end

local spGetUnitDefID = Spring.GetUnitDefID

local trackedUnitsToUnitDefID = {}
local unitDefToTargetingUnitIDs = {}

local POLLING_RATE = 15
local CMD_UNIT_CANCEL_TARGET = GameCMD.UNIT_CANCEL_TARGET
local CMD_SET_TARGET = GameCMD.UNIT_SET_TARGET

local gameStarted

function maybeRemoveSelf()
	if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
		widgetHandler:RemoveWidget()
	end
end

function widget:GameStart()
	gameStarted = true
	maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
	maybeRemoveSelf()
end

function widget:Initialize()
	if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
		maybeRemoveSelf()
	end
end

function widget:GameFrame(frame)
	if frame % POLLING_RATE ~= 0 then
		return
	end
	local allUnits = Spring.GetAllUnits()
	local unitDefToCmd = {}
	for _, unitID in ipairs(allUnits) do
		local def = spGetUnitDefID(unitID)
		if not Spring.IsUnitAllied(unitID) and unitDefToTargetingUnitIDs[def] then				
			if unitDefToCmd[def] == nil then unitDefToCmd[def] = {} end

			local currentCmd = unitDefToCmd[def]
			local newCmdOpts = {}
			if #currentCmd ~= 0  then
				newCmdOpts = { "shift" }
			end

			currentCmd[#currentCmd+1] = { CMD_SET_TARGET, { unitID }, newCmdOpts }
			unitDefToCmd[def] = currentCmd
		end
	end

	-- Issue command arrays to relevant units
	for targetedUnitDefID, unitSet in pairs(unitDefToTargetingUnitIDs) do
		if unitDefToCmd[targetedUnitDefID] ~= nil then			
			local unitArray = {}
			for k, _ in pairs(unitSet) do
				table.insert(unitArray, k)
			end

			if #unitArray > 0 then
				Spring.GiveOrderArrayToUnitArray(unitArray, unitDefToCmd[targetedUnitDefID])
			end
		end
	end
end

local function cleanupUnitTargeting(unitID)
	local oldTargetUnitDefID = trackedUnitsToUnitDefID[unitID]
	if oldTargetUnitDefID and unitDefToTargetingUnitIDs[oldTargetUnitDefID] then
		-- Remove unit from table of units that target the old def
		unitDefToTargetingUnitIDs[oldTargetUnitDefID][unitID] = nil

		-- If it's empty then get rid of it
		if next(unitDefToTargetingUnitIDs[oldTargetUnitDefID]) == nil then
			unitDefToTargetingUnitIDs[oldTargetUnitDefID] = nil
		end
	end

end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	local shouldCleanupTargeting = false
	local selectedUnits = Spring.GetSelectedUnits()
	if cmdID == CMD_UNIT_CANCEL_TARGET then
		shouldCleanupTargeting = true
	end

	if cmdID == CMD_SET_TARGET and not cmdOpts.alt then
		shouldCleanupTargeting = true		
	end

	if cmdID == CMD_SET_TARGET and #cmdParams ~= 1 then
		shouldCleanupTargeting = true
	end

	if shouldCleanupTargeting then
		for _, unitID in ipairs(selectedUnits) do
			cleanupUnitTargeting(unitID)
		end
	end

	if cmdID ~= CMD_SET_TARGET or not cmdOpts.alt or #cmdParams ~= 1 then
		return
	end

	local targetId = cmdParams[1]

	-- We're targeting this unit type for all selected units
	local targetUnitDefID = spGetUnitDefID(targetId)
	-- Initialize table of units that target this unit type if it's not there
	if not unitDefToTargetingUnitIDs[targetUnitDefID] then unitDefToTargetingUnitIDs[targetUnitDefID] = {} end

	for _, unitID in ipairs(selectedUnits) do
		-- In case this unit is targeting a unit type already
		cleanupUnitTargeting(unitID)
		-- Register the unit
		unitDefToTargetingUnitIDs[targetUnitDefID][unitID] = true
		trackedUnitsToUnitDefID[unitID] = targetUnitDefID
	end
end

