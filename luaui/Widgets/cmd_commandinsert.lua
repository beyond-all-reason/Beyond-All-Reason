-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local widget = widget ---@type Widget
local Insert = require("luaui/Include/command_insert")

function widget:GetInfo()
	return {
		name = "CommandInsert",
		desc = "When pressing spacebar and shift, you can insert commands to arbitrary places in queue. When pressing spacebar alone, commands are inserted on front of queue. Based on FrontInsert by jK",
		author = "dizekat",
		date = "Jan,2008",
		license = "GNU GPL, v2 or later",
		layer = 5,
		enabled = true,
	}
end

-- Localized Spring API for performance
local spGetUnitPosition = Spring.GetUnitPosition
local spGetGameFrame = Spring.GetGameFrame
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand

local MAX_QUEUE_WALK = 100

local modifiers = {
	prepend_between = false,
	prepend_queue = false,
}

-- Current position in prepend queue for prepend_queue mode
local prependPositions = {}

function widget:GameStart()
	widget:PlayerChanged()
end

function widget:PlayerChanged()
	if Spring.GetSpectatingState() and spGetGameFrame() > 0 then
		widgetHandler:RemoveWidget()
	end
end

local function pressHandler(_, _, args)
	if not args then
		return
	end

	if modifiers[args[1]] == nil then
		return
	end

	modifiers[args[1]] = true

	if args[1] == "prepend_queue" then
		prependPositions = {}
	end
end

local function releaseHandler(_, _, args)
	if not args then
		return
	end

	if modifiers[args[1]] == nil then
		return
	end

	modifiers[args[1]] = false
end

local insertCommands
local function hasOption(options, flag)
	if options[flag] then
		return true
	end
	for _, value in ipairs(options) do
		if value == flag then
			return true
		end
	end
	return false
end

local function getInsertMode(options)
	return Insert.GetMode(modifiers, hasOption(options, "shift"), hasOption(options, "meta"))
end

function widget:Initialize()
	if Spring.IsReplay() or spGetGameFrame() > 0 then
		widget:PlayerChanged()
		if Spring.GetSpectatingState() then
			return
		end
	end

	WG.commandInsert = {
		GetInsertMode = getInsertMode,
		InsertCommands = function(...)
			return insertCommands(...)
		end,
	}
	widgetHandler:AddAction("commandinsert", pressHandler, nil, "p")
	widgetHandler:AddAction("commandinsert", releaseHandler, nil, "r")
end

local function GetUnitOrFeaturePosition(id)
	if id < Game.maxUnits then
		return spGetUnitPosition(id)
	else
		return Spring.GetFeaturePosition(id - Game.maxUnits)
	end
end

local function GetCommandPos(id, p1, p2, p3) --- get the command position
	if
		id < 0
		or id == CMD.MOVE
		or id == CMD.REPAIR
		or id == CMD.RECLAIM
		or id == CMD.RESURRECT
		or id == CMD.DGUN
		or id == CMD.GUARD
		or id == CMD.FIGHT
		or id == CMD.ATTACK
	then
		if p3 ~= nil then
			return p1, p2, p3
		elseif p1 ~= nil then
			return GetUnitOrFeaturePosition(p1)
		end
	end
	return nil
end

-- Commands use the engine order-array format: { id, params, options }.
-- Returns true when insertion handles the batch; false leaves normal issuing
-- to the caller. An explicit mode captures the action state before dispatch.
-- Resolve the entire batch before sending it: engine queues do not reflect
-- newly sent orders until the simulation receives them.
insertCommands = function(units, commands, options, mode)
	mode = mode or getInsertMode(options)
	if not mode or spGetGameFrame() == 0 or #commands == 0 then
		return false
	end
	local first = { GetCommandPos(commands[1][1], unpack(commands[1][2])) }
	local last = { GetCommandPos(commands[#commands][1], unpack(commands[#commands][2])) }
	if mode == "between" and (not first[1] or not last[1]) then
		return false
	end
	for _, unitID in ipairs(units) do
		local count = spGetUnitCommandCount(unitID)
		local x, y, z = spGetUnitPosition(unitID)
		if count and x then
			local position = 0
			if mode == "prepend" then
				position = prependPositions[unitID] or 0
				prependPositions[unitID] = position + #commands
			elseif mode == "between" then
				local queue = {}
				for j = 1, math.min(count, MAX_QUEUE_WALK) do
					local id, _, _, p1, p2, p3 = spGetUnitCurrentCommand(unitID, j)
					queue[j] = id and { GetCommandPos(id, p1, p2, p3) } or {}
				end
				local index = Insert.FindPosition({ x, y, z }, queue, first, last)
				position = index > #queue and count or index - 1
			end
			for i, command in ipairs(commands) do
				local opts = command[3] or options
				local mask = 0
				for _, flag in ipairs({ "alt", "ctrl", "right", "shift" }) do
					if hasOption(opts, flag) then
						mask = mask + CMD["OPT_" .. flag:upper()]
					end
				end
				spGiveOrderToUnit(
					unitID,
					CMD.INSERT,
					{ position + i - 1, command[1], mask, unpack(command[2]) },
					{ "alt" }
				)
			end
		end
	end
	return true
end

function widget:CommandNotify(id, params, options)
	-- Widget-generated area commands must be expanded before inserting the
	-- resulting build orders. Pregame owns a Lua queue and has no live builders.
	if spGetGameFrame() == 0 or id == GameCMD.AREA_MEX then
		return false
	end
	if not (modifiers.prepend_between or modifiers.prepend_queue) then
		return false
	end
	if not insertCommands(Spring.GetSelectedUnits(), { { id, params } }, options) then
		return false
	end
	if id < 0 then
		Spring.SetActiveCommand(Spring.GetCmdDescIndex(id), 1, true, false, options.alt, options.ctrl, false, false)
	end
	return true
end

function widget:Shutdown()
	WG.commandInsert = nil
	widgetHandler:RemoveAction("commandinsert")
end
