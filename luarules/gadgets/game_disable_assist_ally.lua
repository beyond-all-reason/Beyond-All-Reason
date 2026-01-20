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

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam

local CMD_GUARD = CMD.GUARD
local CMD_REPAIR = CMD.REPAIR
local CMD_INSERT = CMD.INSERT
local CMD_MOVESTATE = CMD.MOVE_STATE

local gaiaTeam = Spring.GetGaiaTeamID()

local canBuildStep = {} -- i.e. anything that spends resources when assisted
for unitDefID, unitDef in ipairs(UnitDefs) do
	canBuildStep[unitDefID] = unitDef.isFactory or (unitDef.isBuilder and (unitDef.canBuild or unitDef.canAssist))
end

local function isComplete(unitID)
	local beingBuilt, buildProgress = Spring.GetUnitIsBeingBuilt(unitID)
	return not beingBuilt or buildProgress >= 1
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_GUARD)
	gadgetHandler:RegisterAllowCommand(CMD_REPAIR)
	gadgetHandler:RegisterAllowCommand(CMD_INSERT)
	gadgetHandler:RegisterAllowCommand(CMD_MOVESTATE)
end

local params = { 0, 0, 0 }
local EMPTY = {} -- stupid

local function resolveCommand(cmdID, cmdParams)
	local p = params
	p[1], p[2], p[3] = cmdParams[4], cmdParams[5], cmdParams[6]
	cmdID, cmdParams = cmdParams[2], p
	if cmdID ~= CMD_GUARD and cmdID ~= CMD_REPAIR then
		return 0, EMPTY
	else
		return cmdID, cmdParams
	end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	if not canBuildStep[unitDefID] then
		return true
	end

	if cmdID == CMD_INSERT then
		cmdID, cmdParams = resolveCommand(cmdID, cmdParams)
	end

	-- Disallow guard commands onto labs, units that have buildOptions or can assist
	if cmdID == CMD_GUARD then
		local targetID = cmdParams[1]
		local targetTeam = Spring.GetUnitTeam(targetID)

		if targetTeam and unitTeam ~= Spring.GetUnitTeam(targetID) and Spring.AreTeamsAllied(unitTeam, targetTeam) then
			if canBuildStep[Spring.GetUnitDefID(targetID)] then
				return false
			end
		end
		return true
	end

	-- Also disallow assisting building (caused by a repair command) units under construction
	-- Area repair doesn't cause assisting, so it's fine that we can't properly filter it
	if cmdID == CMD_REPAIR and #cmdParams == 1 then
		local targetID = cmdParams[1]
		local targetTeam = Spring.GetUnitTeam(targetID)

		if targetTeam and unitTeam ~= Spring.GetUnitTeam(targetID) and Spring.AreTeamsAllied(unitTeam, targetTeam) then
			if not isComplete(targetID) then
				return false
			end
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
			if (command == CMD_GUARD or command == CMD_REPAIR) and (p1 and not p2) and spGetUnitTeam(p1) ~= newTeam then
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
