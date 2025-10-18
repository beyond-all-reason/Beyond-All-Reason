local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name 	= "Set unit type target",
		desc 	= "Hold down Alt and set target on an enemy unit to make selected units set target on all future enemies of that type",
		author  = "Flameink",
		date	= "August 1, 2025",
		version = "1.0",
		license = "GNU GPL, v2 or later",
		layer 	= 0,
		enabled = true
	}
end

local spGetUnitDefID         = Spring.GetUnitDefID
local spGetUnitPosition      = Spring.GetUnitPosition
local spGetUnitsInCylinder   = Spring.GetUnitsInCylinder
local spAreTeamsAllied       = Spring.AreTeamsAllied
local spGetUnitTeam          = Spring.GetUnitTeam
local spGiveOrderArrayToUnit = Spring.GiveOrderArrayToUnit
local spGetSelectedUnits     = Spring.GetSelectedUnits

local trackedUnitsToUnitDefID = {}
local unitRanges = {}
local myAllyTeam = Spring.GetMyAllyTeamID()

local POLLING_RATE = 15
local CMD_UNIT_CANCEL_TARGET = GameCMD.UNIT_CANCEL_TARGET
local CMD_SET_TARGET = GameCMD.UNIT_SET_TARGET
-- Set target on units that aren't in range yet but may come in range soon
local UNIT_RANGE_MULTIPLIER = 1.5

local gameStarted

for udid, ud in pairs(UnitDefs) do
	local maxRange = 0

	for ii, weapon in ipairs(ud.weapons) do
		if weapon.weaponDef then
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if weaponDef then
				if weaponDef.range > maxRange then
					maxRange = weaponDef.range
				end
			end
		end
	end

	unitRanges[udid] = maxRange
end

local function GetUnitsInAttackRangeWithDef(unitID, unitDefIDToTarget)
    local unitsInRange = {}

    local ux, uy, uz = spGetUnitPosition(unitID)
    if not ux then return unitsInRange end

    local maxRange = unitRanges[spGetUnitDefID(unitID)]
    if maxRange == nil or maxRange <= 0 then return unitsInRange end
	maxRange = maxRange * UNIT_RANGE_MULTIPLIER

    local candidateUnits = spGetUnitsInCylinder(ux, uz, maxRange)
	for _, targetID in ipairs(candidateUnits) do
        if targetID ~= unitID then
            local isAllied = spAreTeamsAllied(myAllyTeam, spGetUnitTeam(targetID))
			if not isAllied and spGetUnitDefID(targetID) == unitDefIDToTarget then
				table.insert(unitsInRange, targetID)
            end
        end
    end

    return unitsInRange
end

function widget:GameFrame(frame)
	if frame % POLLING_RATE ~= 0 then
		return
	end

	for unitID, targetUnitDefID in pairs(trackedUnitsToUnitDefID) do
		local candidateUnits = GetUnitsInAttackRangeWithDef(unitID, targetUnitDefID)
		local commandsToGive = {}
		for _, targetID in ipairs(candidateUnits) do
			local newCmdOpts = {}
			if #commandsToGive ~= 0  then
				newCmdOpts = { "shift" }
			end

			commandsToGive[#commandsToGive+1] = { CMD_SET_TARGET, { targetID }, newCmdOpts }			
		end

		spGiveOrderArrayToUnit(unitID, commandsToGive)
	end
end

local function cleanupUnitTargeting(unitID)
	trackedUnitsToUnitDefID[unitID] = nil
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	local shouldCleanupTargeting = false
	local selectedUnits = spGetSelectedUnits()
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
	local targetUnitDefID = spGetUnitDefID(targetId)

	for _, unitID in ipairs(selectedUnits) do
		cleanupUnitTargeting(unitID)
		trackedUnitsToUnitDefID[unitID] = targetUnitDefID
	end
end

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