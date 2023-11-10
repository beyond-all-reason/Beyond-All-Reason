function widget:GetInfo()
	return {
		name = "Command Queue Manager",
		desc = "Skips current command or cancels the last command in command",
		author = "[DE]LSR",
		date = "5 Apr, 2022",
		license = "GNU GPL, v2 or later",
		layer = 1, --  after the normal widgets
		enabled = true, --  loaded by default?
	}
end

-- Handlers
function widget:Initialize()
	widgetHandler:AddAction("command_skip_current", SkipCurrentCommand, nil, "p")
	widgetHandler:AddAction("command_cancel_last", CancelLastCommand, nil, "p")
end

-- Locals
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetCommandQueueSize = Spring.GetCommandQueue
local spGiveOrderToUnit = Spring.GiveOrderToUnit

local CMDREPAIR = CMD.REPAIR
local CMDRECLAIM = CMD.RECLAIM

-- Main functions
function SkipCurrentCommand()
	ProcessSelectedUnits(function(id)
		RemoveCommand(id, 1, spGetCommandQueueSize(id, 0))
	end)
end

function CancelLastCommand()
	ProcessSelectedUnits(function(id)
		local commandQueueSize = spGetCommandQueueSize(id, 0)

		if (not commandQueueSize) or commandQueueSize < 1 then
			return
		end

		RemoveCommand(id, commandQueueSize, commandQueueSize)
	end)
end

-- Helper functions
function RemoveCommand(unitID, cmdIndex, commandQueueSize)
	local cmdID, _, cmdTag, _, cmdParam2 = spGetUnitCurrentCommand(unitID, cmdIndex)

	if (cmdID == CMDRECLAIM or cmdID == CMDREPAIR) and cmdParam2 then -- second param means it is an area order
		local _, _, cmdTag2 = spGetUnitCurrentCommand(unitID, cmdIndex + 1)
		spGiveOrderToUnit(unitID, CMD.REMOVE, { cmdTag2, cmdTag }, 0)
	elseif cmdID then
		spGiveOrderToUnit(unitID, CMD.REMOVE, { cmdTag }, 0)
	end

	-- If there was only one command on queue, issue stop (keeps performing command otherwise)
	if commandQueueSize == 1 then
		spGiveOrderToUnit(unitID, CMD.STOP, {}, 0)
	end
end

function ProcessSelectedUnits(processCommandFunc)
	local selectedUnits = spGetSelectedUnits()

	for i = 1, #selectedUnits do
		local id = selectedUnits[i]
		processCommandFunc(id)
	end
end
