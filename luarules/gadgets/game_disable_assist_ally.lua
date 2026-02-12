local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Disable Assist Ally Construction',
		desc    = 'Disable assisting allied units (e.g. labs and units/buildings under construction) when modoption is enabled',
		author  = 'Rimilel',
		date    = 'April 2024',
		license = 'GNU GPL, v2 or later',
		layer   = 1, -- after unit_mex_upgrade_reclaimer and unit_geo_upgrade_reclaimer
		enabled = Spring.GetModOptions().disable_assist_ally_construction or Spring.GetModOptions().easytax,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder

local CMD_GUARD = CMD.GUARD
local CMD_REPAIR = CMD.REPAIR
local CMD_MOVESTATE = CMD.MOVE_STATE
local MOVESTATE_ROAM = CMD.MOVESTATE_ROAM
local CMD_INSERT = CMD.INSERT

local footprintSize = Game.squareSize * Game.footprintScale

-- Local state

local builderMoveStateCmdDesc = {
	params = { 1, "Hold pos", "Maneuver", --[["Roam"]] },
}

local gaiaTeam = Spring.GetGaiaTeamID()

local isFactory = {}
local canBuildStep = {} -- i.e. anything that spends resources when assisted
for unitDefID, unitDef in ipairs(UnitDefs) do
	isFactory[unitDefID] = unitDef.isFactory
	canBuildStep[unitDefID] = unitDef.isFactory or (unitDef.isBuilder and (unitDef.canBuild or unitDef.canAssist))
end

local checkUnitCommandList = {} -- Delay validating given units so the order of calls to UnitGiven does not matter.

-- Local functions

local function removeRoamMoveState(unitID)
	local index = Spring.FindUnitCmdDesc(unitID, CMD_MOVESTATE)
	if index then
		local moveState = select(2, Spring.GetUnitStates(unitID, false))
		local params = builderMoveStateCmdDesc.params
		params[1] = math.min(moveState or 1, MOVESTATE_ROAM - 1)
		Spring.EditUnitCmdDesc(unitID, index, builderMoveStateCmdDesc)
	end
end

local function isComplete(unitID)
	local beingBuilt, buildProgress = spGetUnitIsBeingBuilt(unitID)
	return not beingBuilt or buildProgress >= 1
end

local function isAlliedUnit(teamID, unitID)
	local unitTeam = unitID and spGetUnitTeam(unitID)
	return unitTeam and teamID ~= unitTeam and spAreTeamsAllied(teamID, unitTeam)
end

-- Awkward, because we get the params in a table format ~half the time.
local function isBuilderAllowedCommand(cmdID, p1, p2, p5, p6, unitTeam)
	if cmdID == CMD_GUARD then
		return not isAlliedUnit(unitTeam, p1) or (isComplete(p1) and not canBuildStep[spGetUnitDefID(p1)])
	elseif cmdID == CMD_REPAIR then
		if p6 or (not p5 and p2) or not p1 then -- check for 1 or 5 arguments
			return true -- Area Repair is okay.
		end
		return not isAlliedUnit(unitTeam, p1) or (isComplete(p1))
	elseif cmdID == CMD_MOVESTATE then
		return p1 ~= MOVESTATE_ROAM
	else
		return true
	end
end

local function validateCommands(unitID, unitTeam)
	local GetUnitCurrentCommand = spGetUnitCurrentCommand
	local tags, count = {}, 0

	for index = 1, Spring.GetUnitCommandCount(unitID) do
		local command, _, tag, p1, p2, _, _, p5, p6 = GetUnitCurrentCommand(unitID, index)
		if not isBuilderAllowedCommand(command, p1, p2, p5, p6, unitTeam) then
			count = count + 1
			tags[count] = tag
		end
	end

	if count > 0 then
		Spring.GiveOrderToUnit(unitID, CMD.REMOVE, tags)
	end
end

local PARAM = table.new(6, 0) -- need to check up to 5+1 arguments
local EMPTY = {}
local insertedCommands = {
	[CMD_GUARD] = true,
	[CMD_REPAIR] = true,
	[CMD_MOVESTATE] = true,
}

local function resolveCommand(cmdParams)
	local cmdID = cmdParams[2] or 0
	if insertedCommands[cmdID] then
		local p = PARAM
		for i = 1, 6 do
			p[i] = cmdParams[i + 3]
		end
		cmdParams = p
	else
		cmdID, cmdParams = 0, EMPTY
	end
	return cmdID, cmdParams
end

-- Engine call-ins

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_GUARD)
	gadgetHandler:RegisterAllowCommand(CMD_REPAIR)
	gadgetHandler:RegisterAllowCommand(CMD_INSERT)
	gadgetHandler:RegisterAllowCommand(CMD_MOVESTATE)
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if canBuildStep[unitDefID] then
		removeRoamMoveState(unitID)
	end

	-- In unit_{xyz}_upgrade_reclaimer, units are transferred instantly,
	-- so we can check immediately whether they are bypassing the rules:
	if builderID and isAlliedUnit(unitTeam, builderID) then
		checkUnitCommandList[unitID] = spGetUnitTeam(builderID)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	checkUnitCommandList[unitID] = nil
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	if not canBuildStep[unitDefID] then
		return true
	end

	if cmdID == CMD_INSERT then
		cmdID, cmdParams = resolveCommand(cmdParams)
	end

	return isBuilderAllowedCommand(cmdID, cmdParams[1], cmdParams[2], cmdParams[5], cmdParams[6], unitTeam)
end

function gadget:AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z, facing)
	-- Identical blueprints placed on top of one another are converted to build assist.
	if builderID and not isFactory[spGetUnitDefID(builderID)] then
		local units = spGetUnitsInCylinder(x, z, footprintSize)
		for _, unitID in pairs(units) do
			if unitDefID == spGetUnitDefID(unitID) and not isComplete(unitID) and isAlliedUnit(builderTeam, unitID) then
				return false, false
			end
		end
	end
	return true, true
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if newTeam ~= gaiaTeam and canBuildStep[unitDefID] then
		checkUnitCommandList[unitID] = newTeam
	end
end

local function _GameFramePost(unitList)
	local GetUnitIsDead = Spring.GetUnitIsDead
	for unitID, newTeam in pairs(unitList) do
		unitList[unitID] = nil
		if GetUnitIsDead(unitID) == false then
			validateCommands(unitID, newTeam)
		end
	end
end
function gadget:GameFramePost()
	-- We rarely need to call this function:
	if next(checkUnitCommandList) then
		_GameFramePost(checkUnitCommandList)
	end
end

-- Temp anti-cheat-esque guard. We check on random frames for units bypassing the rules.
local function AllowUnitBuildStep(self, builderID, builderTeam, unitID, unitDefID, part)
    if part > 0 and builderTeam ~= spGetUnitTeam(unitID) and not isComplete(unitID) then
		checkUnitCommandList[builderID] = builderTeam
		return false
    end
	return true
end

local seed = math.random(91, 119) -- skip spawn-in frames

function gadget:GameFrame(frame)
    if frame % seed == 0 then
        gadget.AllowUnitBuildStep = AllowUnitBuildStep
        gadgetHandler:UpdateCallIn("AllowUnitBuildStep")
    elseif gadget.AllowUnitBuildStep then
        gadget.AllowUnitBuildStep = nil
        gadgetHandler:UpdateCallIn("AllowUnitBuildStep")
        seed = math.random(1, 119)
    end
end
