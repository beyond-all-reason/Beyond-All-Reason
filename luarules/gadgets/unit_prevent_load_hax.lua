--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Prevent Load Hax",
		desc = "Prevent Load Hax",
		author = "TheFatController",
		date = "Jul 20, 2009",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if not gadgetHandler:IsSyncedCode() then
	return false
end

local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitPosition = Spring.GetUnitPosition
local GetUnitSeparation = Spring.GetUnitSeparation
local GetGameFrame = Spring.GetGameFrame
local GetUnitCommands = Spring.GetUnitCommands
local GetUnitCommandCount = Spring.GetUnitCommandCount
local GetUnitTeam = Spring.GetUnitTeam

local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_MOVE = CMD.MOVE
local CMD_REMOVE = CMD.REMOVE
local CMD_OPT_ALT = CMD.OPT_ALT
local CMD_OPT_SHIFT = CMD.OPT_SHIFT

local giveInsertOrderToUnit = Game.Commands.GiveInsertOrderToUnit

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local watchList = {}

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_REMOVE)
	gadgetHandler:RegisterAllowCommand(CMD_LOAD_UNITS)
end

local function getInsertIndex(unitID, cmdTag, fromInsert)
	if fromInsert.alt then
		local queueSize = GetUnitCommandCount(unitID)
		local index = math.modf(cmdTag)
		if index < 0 then
			index = index + queueSize + 1
		end
		return math.min(math.max(index, 0), queueSize)
	end
	local queue = GetUnitCommands(unitID, -1)
	for i = 1, #queue do
		if queue[i].tag == cmdTag then
			return fromInsert.right and i or i - 1
		end
	end
end

local function giveMoveThenLoad(unitID, moveX, moveY, moveZ, cmdParams, cmdOptions, cmdTag, fromInsert)
	if not fromInsert then
		GiveOrderToUnit(unitID, CMD_MOVE, { moveX, moveY, moveZ }, cmdOptions.coded)
		GiveOrderToUnit(unitID, CMD_LOAD_UNITS, cmdParams, CMD_OPT_SHIFT)
		return
	end
	local index = getInsertIndex(unitID, cmdTag, fromInsert)
	if index then
		giveInsertOrderToUnit(unitID, CMD_MOVE, { moveX, moveY, moveZ }, cmdOptions, index, CMD_OPT_ALT)
		giveInsertOrderToUnit(unitID, CMD_LOAD_UNITS, cmdParams, cmdOptions, index + 1, CMD_OPT_ALT)
	end
end

local function allowLoadUnits(unitID, cmdParams, cmdOptions, cmdTag, fromInsert)
	if cmdParams[4] then
		local tx, ty, tz = GetUnitPosition(unitID)
		local dist =
			math.sqrt(((cmdParams[1] - tx) * (cmdParams[1] - tx)) + ((cmdParams[3] - tz) * (cmdParams[3] - tz)))
		if dist < math.max(100, cmdParams[4]) then
			local angle = (math.random() * 6.28) - 3.14
			local moveX, moveZ = cmdParams[1] + (math.sin(angle) * 120), cmdParams[3] + (math.cos(angle) * 120)
			giveMoveThenLoad(unitID, moveX, ty, moveZ, cmdParams, cmdOptions, cmdTag, fromInsert)
			watchList[unitID] = GetGameFrame() + 45
			return false
		else
			return true
		end
	else
		local dist = GetUnitSeparation(unitID, cmdParams[1])
		if not dist then
			return false
		end
		if (dist < 80) and (GetUnitTeam(unitID) ~= GetUnitTeam(cmdParams[1])) then
			local tx, ty, tz = GetUnitPosition(unitID)
			local ux, _, uz = GetUnitPosition(cmdParams[1])
			local angle = math.atan2((tx - ux), (tz - uz))
			local moveX, moveZ = ux + (math.sin(angle) * 100), uz + (math.cos(angle) * 100)
			giveMoveThenLoad(unitID, moveX, ty, moveZ, cmdParams, cmdOptions, cmdTag, fromInsert)
			watchList[unitID] = GetGameFrame() + 45
			return false
		else
			return true
		end
	end
end

function gadget:AllowCommand(
	unitID,
	unitDefID,
	teamID,
	cmdID,
	cmdParams,
	cmdOptions,
	cmdTag,
	playerID,
	fromSynced,
	fromLua,
	fromInsert
)
	if fromSynced then
		return true
	end
	if fromInsert then
		if watchList[unitID] then
			return false
		end
		if cmdID == CMD_LOAD_UNITS then
			return allowLoadUnits(unitID, cmdParams, cmdOptions, cmdTag, fromInsert)
		end
		local cQueue = GetUnitCommands(unitID, 20)
		if #cQueue > 0 then
			for i = 1, #cQueue do
				local command = cQueue[i]
				if (command.id == CMD_LOAD_UNITS) and (#command.params == 1) then
					watchList[unitID] = GetGameFrame() + 30
					return false
				end
			end
		end
	elseif cmdID == CMD_REMOVE then
		if watchList[unitID] then
			return false
		end
		local cQueue = GetUnitCommands(unitID, 20)
		if #cQueue > 0 then
			for i = 1, #cQueue do
				local command = cQueue[i]
				if (command.id == CMD_LOAD_UNITS) and (#command.params == 1) then
					watchList[unitID] = GetGameFrame() + 30
					return false
				end
			end
		end
	elseif cmdID == CMD_LOAD_UNITS then
		return allowLoadUnits(unitID, cmdParams, cmdOptions)
	end
	return true
end

function gadget:GameFrame(n)
	for unitID, t in pairs(watchList) do
		if n > t then
			watchList[unitID] = nil
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
