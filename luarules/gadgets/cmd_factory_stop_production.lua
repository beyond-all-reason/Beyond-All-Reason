--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name = "Factory Stop Production",
		desc = "Adds a command to clear the factory queue",
		author = "GoogleFrog,badosu",
		date = "13 November 2016",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if not gadgetHandler:IsSyncedCode() then
	return false --  no unsynced code
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spGetRealBuildQueue = Spring.GetRealBuildQueue
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc

local CMD_WAIT = CMD.WAIT
local EMPTY = {}
local DEQUEUE_OPTS = { "right", "ctrl", "shift" } -- right: dequeue, ctrl+shift: 100

include("luarules/configs/customcmds.h.lua")

local isFactory = {}
for udid = 1, #UnitDefs do
	local ud = UnitDefs[udid]
	if ud.isFactory then
		isFactory[udid] = true
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local stopProductionCmdDesc = {
	id = CMD_STOP_PRODUCTION,
	type = CMDTYPE.ICON,
	name = "Stop Production",
	action = "stopproduction",
	cursor = "Stop", -- Probably does nothing
	tooltip = "Stop Production: Clear factory production queue.",
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Handle the command

function gadget:AllowCommand_GetWantedCommand()
	return { [CMD_STOP_PRODUCTION] = true }
end

function gadget:AllowCommand_GetWantedUnitDefID()
	return isFactory
end

local function orderDequeue(unitID, buildDefID, count)
	while count > 0 do
		-- The commented code below might still be useful in some circumstance we need 'perfect' dequeue
		--
		-- if count >= 100 then
		count = count - 100
		-- elseif count >= 20 then
		-- 	opts = { "ctrl" }
		-- 	count = count - 20
		-- elseif count >= 5 then
		-- 	opts = { "shift" }
		-- 	count = count - 5
		-- else
		-- 	count = count - 1
		-- end

		spGiveOrderToUnit(unitID, -buildDefID, EMPTY, DEQUEUE_OPTS)
	end
end

function gadget:AllowCommand(unitID, unitDefID, _, cmdID)
	if (cmdID ~= CMD_STOP_PRODUCTION) or not isFactory[unitDefID] then
		return true
	end

	-- Dequeue build order by sending build command to factory to minimize number of commands sent
	-- As opposed to removing each build command individually
	local queue = spGetRealBuildQueue(unitID)

	if queue ~= nil then
		for _, buildPair in ipairs(queue) do
			local buildUnitDefID, count = next(buildPair, nil)

			orderDequeue(unitID, buildUnitDefID, count)
		end
	end

	spGiveOrderToUnit(unitID, CMD_WAIT, EMPTY, 0) -- Removes wait if there is a wait but doesn't readd it.
	spGiveOrderToUnit(unitID, CMD_WAIT, EMPTY, 0) -- If a factory is waiting, it will not clear the current build command, even if the cmd is removed.
	-- See: http://zero-k.info/Forum/Post/237176#237176 for details.
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Add the command to factories

function gadget:UnitCreated(unitID, unitDefID)
	if isFactory[unitDefID] then
		spInsertUnitCmdDesc(unitID, stopProductionCmdDesc)
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterCMDID(CMD_STOP_PRODUCTION)
	for _, unitID in pairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end
