local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Disable Assist Ally Construction',
		desc    = 'Disable assisting allied units (e.g. labs and units/buildings under construction) when modoption is enabled',
		author  = 'Rimilel',
		date    = 'April 2024',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = Spring.GetModOptions().disable_assist_ally_construction or Spring.GetModOptions().easytax,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitTeam = Spring.GetUnitTeam

local CMD_GUARD = CMD.GUARD
local CMD_REPAIR = CMD.REPAIR
local CMD_MOVESTATE = CMD.MOVE_STATE
local CMD_INSERT = CMD.INSERT

local gaiaTeam = Spring.GetGaiaTeamID()

local canBuildStep = {} -- i.e. anything that spends resources when assisted
for unitDefID, unitDef in ipairs(UnitDefs) do
	canBuildStep[unitDefID] = unitDef.isFactory or (unitDef.isBuilder and (unitDef.canBuild or unitDef.canAssist))
end

local function isComplete(unitID)
	local beingBuilt, buildProgress = spGetUnitIsBeingBuilt(unitID)
	return not beingBuilt or buildProgress >= 1
end

local function isAlliedUnit(teamID, unitID)
	local unitTeam = spGetUnitTeam(unitID)
	return unitTeam and teamID ~= unitTeam and spAreTeamsAllied(teamID, unitTeam)
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_GUARD)
	gadgetHandler:RegisterAllowCommand(CMD_REPAIR)
	gadgetHandler:RegisterAllowCommand(CMD_INSERT)
	gadgetHandler:RegisterAllowCommand(CMD_MOVESTATE)
end

local PARAM = table.new(6, 0) -- need to check up to 5+1 arguments
local EMPTY = {}

local function resolveCommand(cmdParams)
	local cmdID = cmdParams[1] or 0
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

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	if not canBuildStep[unitDefID] then
		return true
	end

	if cmdID == CMD_INSERT then
		cmdID, cmdParams = resolveCommand(cmdParams)
	end

	-- Disallow guard commands onto labs, units that have buildOptions or can assist
	if cmdID == CMD_GUARD then
		local targetID = cmdParams[1]
		if isAlliedUnit(unitTeam, targetID) and canBuildStep[spGetUnitDefID(targetID)] then
			return false
		end
		return true
	end

	-- Also disallow assisting building (caused by a repair command) units under construction
	-- Area repair doesn't cause assisting, so it's fine that we can't properly filter it
	if cmdID == CMD_REPAIR and #cmdParams == 1 then
		local targetID = cmdParams[1]
		if isAlliedUnit(unitTeam, targetID) and not isComplete(targetID) then
			return false
		end
		return true
	end

	-- Disallow setting builders to roam because roam + fight lets them assist a
	if cmdID == CMD_MOVESTATE and cmdParams[1] == 2 then
		return false
	end

	return true
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if newTeam ~= gaiaTeam and canBuildStep[unitDefID] then
		local tags, count = {}, 0
		local command, _, tag, p1, p2
		local GetUnitCurrentCommand = Spring.GetUnitCurrentCommand
		for index = 1, Spring.GetUnitCommandCount(unitID) do
			command, _, tag, p1, p2 = GetUnitCurrentCommand(unitID, index)
			if (command == CMD_GUARD or command == CMD_REPAIR) and (p1 and not p2) and isAlliedUnit(newTeam, p1) then
				if not isComplete(p1) or (command == CMD_GUARD and canBuildStep[spGetUnitDefID(p1)]) then
					count = count + 1
					tags[count] = tag
				end
			end
		end
		if count > 0 then
			Spring.GiveOrderToUnit(unitID, CMD.REMOVE, tags)
		end
	end
end
