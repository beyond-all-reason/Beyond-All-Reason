local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Suspended Unit Handler",
		desc    = "Prevent actions by units that are stunned, trapped, or disabled.",
		author  = "efrec",
		date    = "2025",
		version = "1.0",
		license = "GNU GPL, v2 or later",
		layer   = -999999, -- preempt most gadgets to act as a source-of-truth
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

-- The suspended state is a counterpart to paralysis for incapacitated units,
-- such as when units enter water deeper than their maximum water depth limit.

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

---Control player and team intel access to a unit's suspension state (on/off).
local accessLevel = { inlos = true } ---@type losAccess

---Immediately remove commands from the unit's queue when it is suspended.
--
-- Units that are completely unrecoverable should have the commands given in
-- this table (or all commands) removed from their command queues.
---@type table<CMD, true>
local commandSuspendRemoves = {
	[CMD.BUILD]        = true,

	[CMD.MOVE]         = true,
	[CMD.GUARD]        = true,
	[CMD.FIGHT]        = true,
	[CMD.PATROL]       = true,

	[CMD.LOAD_ONTO]    = true,
	[CMD.LOAD_UNITS]   = true,
	[CMD.UNLOAD_UNIT]  = true,
	[CMD.UNLOAD_UNITS] = true,

	[CMD.GATHERWAIT]   = true,
	[CMD.SQUADWAIT]    = true,

	[CMD.CAPTURE]      = true,
	[CMD.RECLAIM]      = true,
	[CMD.REPAIR]       = true,
	[CMD.RESURRECT]    = true,
	[CMD.RESTORE]      = true,
}

---Prevent the unit from accepting commands when it is suspended.
--
-- Regardless how they were suspended, all units will reject these commands.
---@type table<CMD, true>
local commandSuspendDisallows = {
	[CMD.BUILD]        = true,

	[CMD.MOVE]         = true,
	[CMD.LOAD_ONTO]    = true,
	[CMD.LOAD_UNITS]   = true,
	[CMD.UNLOAD_UNIT]  = true,
	[CMD.UNLOAD_UNITS] = true,

	[CMD.GATHERWAIT]   = true,
	[CMD.SQUADWAIT]    = true,

	[CMD.CAPTURE]      = true,
	[CMD.RECLAIM]      = true,
	[CMD.REPAIR]       = true,
	[CMD.RESURRECT]    = true,
	[CMD.RESTORE]      = true,
}

--------------------------------------------------------------------------------
-- Global values ---------------------------------------------------------------

local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local spGetUnitPhysicalState = Spring.GetUnitPhysicalState

local CMD_REMOVE = CMD.REMOVE
local OPT_ALT = CMD.OPT_ALT

-- todo: put somewhere
local PSTATE = {
	-- Positional states
	ONGROUND    = 2 ^ 0,
	INWATER     = 2 ^ 1,
	UNDERWATER  = 2 ^ 2,
	UNDERGROUND = 2 ^ 3,
	INAIR       = 2 ^ 4,
	INVOID      = 2 ^ 5,
	-- Impulsive states
	MOVING      = 2 ^ 6,
	FLYING      = 2 ^ 7,
	SKIDDING    = 2 ^ 8,
	FALLING     = 2 ^ 9,
	CRASHING    = 2 ^ 10,
	BLOCKING    = 2 ^ 11,
}

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

local removeIDs = {}
local suspendMovement =
	(commandSuspendRemoves[CMD.ANY] or commandSuspendRemoves[CMD.MOVE]) and
	(commandSuspendDisallows[CMD.ANY] or commandSuspendDisallows[CMD.MOVE])

for command, check in pairs(commandSuspendRemoves) do
	-- Skip meta-commands like CMD.ANY, CMD.NIL:
	if type(command) == "number" and check then
		removeIDs[#removeIDs + 1] = command
	end
end

local removeCommands
do
	if commandSuspendRemoves[CMD.ANY] then
		removeCommands = function(unitID)
			spGiveOrderToUnit(unitID, CMD.STOP)
		end
	elseif commandSuspendRemoves[CMD.BUILD] then
		removeCommands = function(unitID)
			spGiveOrderToUnit(unitID, CMD_REMOVE, removeIDs, OPT_ALT)

			local build = {}
			local index = 1

			repeat
				local command = Spring.GetUnitCurrentCommand(unitID, index)
				if command == nil then
					break
				elseif command < 0 then
					build[command] = true
				end
				index = index + 1
			until false

			if next(build) then
				local sequence = {}
				for id in pairs(build) do
					sequence[#sequence + 1] = id
				end
				spGiveOrderToUnit(unitID, CMD_REMOVE, sequence, OPT_ALT)
			end
		end
	elseif not next(commandSuspendRemoves) then
		removeCommands = function() end
	else
		removeCommands = function(unitID)
			spGiveOrderToUnit(unitID, CMD_REMOVE, removeIDs, OPT_ALT)
		end
	end
end

if commandSuspendDisallows[CMD.ANY] then
	commandSuspendDisallows = setmetatable({}, {
		__index = function(self, value)
			return true
		end
	})
elseif commandSuspendDisallows[CMD.BUILD] then
	commandSuspendDisallows[CMD.BUILD] = nil
	commandSuspendDisallows = setmetatable(commandSuspendDisallows, {
		__index = function(self, value)
			return value < 0 -- disallow build orders
		end
	})
end

--------------------------------------------------------------------------------
-- Suspension handler internals ------------------------------------------------

-- Used for determining which units should slow to a stop:
local PSTATE_IGNORE = math.bit_or(PSTATE.UNDERGROUND, PSTATE.INVOID, PSTATE.CRASHING)

-- todo: Should there be checks for this? Frictionless spherical cows won't slow down in a vacuum.
-- todo: On the other hand why should they? If you make frictionless spherical cows, that's on you.
-- local PSTATE_DRAG     = math.bit_or(PSTATE.FLYING, PSTATE.SKIDDING, PSTATE.FALLING)
-- local PSTATE_FRICTION = math.bit_or(PSTATE.ONGROUND, PSTATE.SKIDDING)
-- local PSTATE_GRAVITY  = math.bit_or(PSTATE.INWATER, PSTATE.UNDERWATER, PSTATE.INAIR, PSTATE.FLYING)

local suspendReasons = {
	-- Engine (stunned units):
	UnitStunned      = "UnitStunned",
	UnitBeingBuilt   = "UnitFinished",
	UnitCloaked      = "UnitDecloaked", -- see `Spring.SetUnitCloak`
	UnitLoaded       = "UnitUnloaded",

	-- Game:
	UnitEnteredAir   = "UnitLeftAir",
	UnitEnteredWater = "UnitLeftWater",
	UnitLeftAir      = "UnitEnteredAir",
	UnitLeftWater    = "UnitEnteredWater",
}

local suspendNotifyList = {}
local suspendNotifyDepth = 0

local function suspendNotify(unitID, suspended)
	suspendNotifyDepth = suspendNotifyDepth + 1

	if suspendNotifyDepth > 16 then
		Spring.Log("SuspendNotify", LOG.ERROR, "Max recursion depth exceeded.")
		return
	end

	for i = 1, #suspendNotifyList do
		suspendNotifyList[i](unitID, suspended)
	end

	suspendNotifyDepth = suspendNotifyDepth - 1
end

local function canMoveCtrl(unitID)
	return math.bit_and(spGetUnitPhysicalState(unitID), PSTATE_IGNORE) ~= PSTATE_IGNORE
end

--------------------------------------------------------------------------------
-- Suspension API --------------------------------------------------------------

local suspendedUnits = {}
local suspendedMoveCtrl = {}
local postponedMoveCtrl = {}

---Map your gadget's special-purpose disable to its re-enable reason.
--
-- General disable/enable functionality is part of the unit suspend handler.
---@param suspend string
---@param resume string
local function addUnitSuspendAndResumeReason(suspend, resume)
	if suspend ~= nil and resume ~= nil and suspendReasons[suspend] == nil then
		suspendReasons[suspend] = resume
		return true
	else
		return false
	end
end

---Add a callback function to be invoked when a unit is suspended or unsuspended.
---@param callback function
--
-- `callback` annotation:
-- @param unitID integer
-- @param suspended boolean
local function registerSuspendNotify(callback)
	if type(callback) == "function" then
		suspendNotifyList[#suspendNotifyList + 1] = callback
	end
end

---Disables movement on a unit and sends it into a stall (with no fall damage anticipated).
--
-- Does not require that the target unit is suspended via the suspension handler.
---@param unitID integer
---@return boolean isDisabled
local function stopMoving(unitID)
	if suspendedMoveCtrl[unitID] ~= nil or postponedMoveCtrl[unitID] ~= nil then
		return true
	end

	if not canMoveCtrl(unitID) then
		postponedMoveCtrl[unitID] = true
		return false -- ambiguous case
	end

	local enabledMoveCtrl = Spring.MoveCtrl.IsEnabled(unitID)
	local restoreBlocking = Spring.GetUnitBlocking(unitID)
	local restoreMoveType ---@type table<function, table>

	if enabledMoveCtrl then
		Spring.MoveCtrl.Disable(unitID) -- seems bad
	end

	if not restoreBlocking then
		Spring.SetUnitBlocking(unitID, true) -- so that air units become blocking
	end

	local moveType = spGetUnitMoveTypeData(unitID)

	if moveType then
		-- Give a sluggish, stalled appearance to any remaining unit movement.
		-- Units with rotating turrets and torsos still spin at normal speeds.
		if moveType.name == "ground" then
			local setMoveType = Spring.MoveCtrl.SetGroundMoveTypeData
			local stalled = table.copy(moveType)
			stalled.turnRate = stalled.turnRate * 0.125
			stalled.accRate = 0
			stalled.maxReverseSpeed = 0
			stalled.wantedSpeed = 0
			setMoveType(unitID, stalled)
			restoreMoveType = { setMoveType, moveType }
		elseif moveType.name == "gunship" then
			local setMoveType = Spring.MoveCtrl.SetGunshipMoveTypeData
			local stalled = table.copy(moveType)
			stalled.turnRate = stalled.turnRate * 0.125
			stalled.accRate = 0
			stalled.decRate = (stalled.decRate or 1) * 0.5 -- sluggish -> drifting
			stalled.altitudeRate = 0
			setMoveType(unitID, stalled)
			restoreMoveType = { setMoveType, moveType }
		elseif moveType.name == "airplane" then
			local setMoveType = Spring.MoveCtrl.SetAirMoveTypeData
			local stalled = table.copy(moveType)
			stalled.altitudeRate = 0
			stalled.maxAileron = 0
			stalled.maxElevator = 0
			stalled.maxRudder = 0
			setMoveType(unitID, stalled)
			restoreMoveType = { setMoveType, moveType }
		end
	end

	suspendedMoveCtrl[unitID] = {
		moveCtrlDisable = not enabledMoveCtrl,
		restoreBlocking = not restoreBlocking,
		restoreMoveType = restoreMoveType,
	}

	return true
end

---Restores the unit's moveType to its previous state when it was first disabled.
--
-- Does not require that the target unit is suspended via the suspension handler,
-- and safe to call for units that have not had their movement disabled.
---@param unitID integer
---@return boolean canMove
local function resumeMoving(unitID)
	local moveCtrl = suspendedMoveCtrl[unitID]
	if moveCtrl then
		if moveCtrl.restoreMoveType then
			local setMoveTypeData = moveCtrl.restoreMoveType[1]
			local moveTypeData = moveCtrl.restoreMoveType[2]
			setMoveTypeData(moveTypeData)
		end
		if moveCtrl.restoreBlocking then
			Spring.SetUnitBlocking(unitID, false)
		end
		if moveCtrl.moveCtrlDisable then
			Spring.MoveCtrl.Enable(unitID)
		end
		suspendedMoveCtrl[unitID] = nil
	end
	postponedMoveCtrl[unitID] = nil
	return true
end

---Disable the unit and set the reason why it cannot take actions.
---@param unitID integer
---@param reason string?
---@param remove boolean? whether to clear disallowed commands from the command queue
---@return string? enableReason
local function addSuspendReason(unitID, reason, remove)
	local suspendedUnit = suspendedUnits[unitID]

	if suspendedUnit == nil then
		spSetUnitRulesParam(unitID, "suspended", 1, accessLevel)
		suspendedUnit = {}
		if remove ~= false then
			removeCommands(unitID)
		end
		if suspendMovement then
			stopMoving(unitID)
		end
		suspendNotify(unitID, true)
	end

	if reason ~= nil then
		local enableReason = suspendReasons[reason] or reason
		suspendedUnit[enableReason] = true
		return enableReason
	end
end

---Clear a disable reason on the unit and attempt to re-enable it.
---@param unitID integer
---@param reason string?
---@return boolean enabled
local function clearSuspendReason(unitID, reason)
	local suspendedUnit = suspendedUnits[unitID]

	if suspendedUnit == nil then
		return true
	end

	local enableReason = reason ~= nil and suspendReasons[reason]

	if enableReason then
		suspendedUnit[enableReason] = nil
	end

	if not enableReason or next(suspendedUnit) == nil then
		spSetUnitRulesParam(unitID, "suspended", 0, accessLevel)
		suspendedUnits[unitID] = nil
		resumeMoving(unitID)
		suspendNotify(unitID, false)
		return true
	end

	return false
end

---@param unitID integer
local function getUnitIsSuspended(unitID)
	return suspendedUnits[unitID] ~= nil
end

---@param unitID integer
---@return string[]? enableReasons
local function getUnitSuspendReasons(unitID)
	local suspendedUnit = suspendedUnits[unitID]
	if suspendedUnit ~= nil then
		local reasons = {}
		for reason in pairs(suspendedUnit) do
			reasons[#reasons + 1] = reason
		end
		return reasons
	end
end

local function getUnitIsSuspendedMoveCtrl(unitID)
	return suspendedMoveCtrl[unitID] ~= nil
end

GG.AddUnitSuspendAndResumeReason = addUnitSuspendAndResumeReason
GG.RegisterSuspendNotify         = registerSuspendNotify
GG.AddSuspendReason              = addSuspendReason
GG.ClearSuspendReason            = clearSuspendReason
GG.GetUnitIsSuspended            = getUnitIsSuspended
GG.GetUnitSuspendReasons         = getUnitSuspendReasons
GG.SuspendMovement               = stopMoving
GG.ResumeMovement                = resumeMoving
GG.GetUnitIsSuspendedMoveCtrl    = getUnitIsSuspendedMoveCtrl

--------------------------------------------------------------------------------
-- Engine callins --------------------------------------------------------------

function gadget:Initialize()
	for command in pairs(commandSuspendDisallows) do
		gadgetHandler:RegisterAllowCommand(command)
	end
end

function gadget:Shutdown()
	GG.AddSuspendReason              = nil
	GG.ClearSuspendReason            = nil
	GG.AddUnitSuspendAndResumeReason = nil
	GG.RegisterSuspendNotify         = nil
	GG.GetUnitIsSuspended            = nil
	GG.GetUnitSuspendReasons         = nil
	GG.SuspendMovement               = nil
	GG.ResumeMovement                = nil
	GG.GetUnitIsSuspendedMoveCtrl    = nil
end

if suspendMovement then
	function gadget:GameFrame(frame)
		-- For units sent flying that halt, trapped in void that recover, etc:
		for unitID in pairs(postponedMoveCtrl) do
			if not canMoveCtrl(unitID) then
				postponedMoveCtrl[unitID] = nil
				stopMoving(unitID)
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	suspendedUnits[unitID] = nil
	suspendedMoveCtrl[unitID] = nil
	postponedMoveCtrl[unitID] = nil
end

-- Removing suspensions --------------------------------------------------------

for suspend, resume in pairs(suspendReasons) do
	gadget[resume] = function(_, unitID)
		if suspendedUnits[unitID] ~= nil then
			clearSuspendReason(unitID, resume)
		end
	end
end

-- One of these generic callins, UnitStunned, works differently:

function gadget:UnitStunned(unitID, unitDefID, unitTeam, stunned)
	if stunned then
		addSuspendReason(unitID, "UnitStunned", false)
	elseif suspendedUnits[unitID] then
		clearSuspendReason(unitID, "UnitStunned")
	end
end

-- Suspension behaviors --------------------------------------------------------

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
	return not suspendedUnits[unitID] or not commandSuspendDisallows[cmdID]
end

-- Use the Allow* callins to fail attempts at tasks as early as possible,
-- so that other gadgets can handle the failure cases as early as possible.

local function shouldAllow(_, unitID)
	return suspendedUnits[unitID] == nil
end

if commandSuspendDisallows[CMD.ATTACK] then
	gadget.AllowWeaponTargetCheck = shouldAllow
	gadget.AllowUnitKamikaze = shouldAllow
end

if commandSuspendDisallows[CMD.CLOAK] then
	-- Note: We don't actually remove the cloaked state (or clear any state).
	gadget.AllowUnitCloak = shouldAllow
end

if commandSuspendDisallows[CMD.LOAD_UNITS] and commandSuspendDisallows[CMD.UNLOAD_UNIT] then
	gadget.AllowUnitTransport = shouldAllow
elseif commandSuspendDisallows[CMD.LOAD_UNITS] then
	gadget.AllowUnitTransportLoad = shouldAllow
elseif commandSuspendDisallows[CMD.UNLOAD_UNIT] then
	gadget.AllowUnitTransportUnload = shouldAllow
end

if commandSuspendDisallows[CMD.CAPTURE] then
	gadget.AllowUnitCaptureStep = shouldAllow
end

if commandSuspendDisallows[CMD.RECLAIM] and commandSuspendDisallows[CMD.REPAIR] then
	gadget.AllowUnitBuildStep = shouldAllow
elseif commandSuspendDisallows[CMD.RECLAIM] then
	function gadget:AllowUnitBuildStep(builderID, builderTeam, featureID, featureDefID, part)
		return part > 0 or suspendedUnits[unitID] == nil
	end
elseif commandSuspendDisallows[CMD.RESURRECT] then
	function gadget:AllowUnitBuildStep(builderID, builderTeam, featureID, featureDefID, part)
		return part < 0 or suspendedUnits[unitID] == nil
	end
end

if commandSuspendDisallows[CMD.RECLAIM] and commandSuspendDisallows[CMD.RESURRECT] then
	gadget.AllowFeatureBuildStep = shouldAllow
elseif commandSuspendDisallows[CMD.RECLAIM] then
	function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
		return part > 0 or suspendedUnits[unitID] == nil
	end
elseif commandSuspendDisallows[CMD.RESURRECT] then
	function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
		return part < 0 or suspendedUnits[unitID] == nil
	end
end
