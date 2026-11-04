-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local widget = widget ---@type Widget

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

local math_sqrt = math.sqrt

local modifiers = {
	prepend_between = false,
	prepend_queue = false,
}

-- Current position in prepend queue for prepend_queue mode
local prependPos = 0

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
		prependPos = 0
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

function widget:Initialize()
	if Spring.IsReplay() or spGetGameFrame() > 0 then
		widget:PlayerChanged()
	end

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
	return -10, -10, -10
end

function widget:CommandNotify(id, params, options)
	if not (modifiers.prepend_between or modifiers.prepend_queue) then
		return false
	end

	local opt = 0
	if options.alt then
		opt = opt + CMD.OPT_ALT
	end
	if options.ctrl then
		opt = opt + CMD.OPT_CTRL
	end
	if options.right then
		opt = opt + CMD.OPT_RIGHT
	end
	-- options.meta not forwarded since we're doing insert with it
	-- and don't want to alias with engine at the same time.
	if options.shift then
		opt = opt + CMD.OPT_SHIFT

		if modifiers.prepend_queue then
			Spring.GiveOrder(CMD.INSERT, { prependPos, id, opt, unpack(params) }, { "alt" })

			prependPos = prependPos + 1

			return true
		end
	else
		Spring.GiveOrder(CMD.INSERT, { 0, id, opt, unpack(params) }, { "alt" })

		return true
	end

	-- Spring.GiveOrder(CMD.INSERT,{0,id,opt,unpack(params)},{"alt"})
	local cx, cy, cz = GetCommandPos(id, params[1], params[2], params[3])
	if cx < -1 then
		return false
	end

	local units = Spring.GetSelectedUnits()
	for i = 1, #units do
		local unit_id = units[i]
		local commandCount = math.min(spGetUnitCommandCount(unit_id) or 0, MAX_QUEUE_WALK)
		local px, py, pz = spGetUnitPosition(unit_id)
		local min_dlen = 1000000
		local insert_pos = 0
		for j = 1, commandCount do
			local cmdID, _, _, p1, p2, p3 = spGetUnitCurrentCommand(unit_id, j)
			local px2, py2, pz2 = GetCommandPos(cmdID, p1, p2, p3)
			if px2 and px2 > -1 then
				local dlen = math_sqrt(
					((px2 - cx) * (px2 - cx)) + ((py2 - cy) * (py2 - cy)) + ((pz2 - cz) * (pz2 - cz))
				) + math_sqrt(((px - cx) * (px - cx)) + ((py - cy) * (py - cy)) + ((pz - cz) * (pz - cz))) - math_sqrt(
					(((px2 - px) * (px2 - px)) + ((py2 - py) * (py2 - py)) + ((pz2 - pz) * (pz2 - pz)))
				)
				if dlen < min_dlen then
					min_dlen = dlen
					insert_pos = j
				end
				px, py, pz = px2, py2, pz2
			end
		end
		-- check for insert at end of queue if its shortest walk.
		local dlen = math_sqrt(((px - cx) * (px - cx)) + ((py - cy) * (py - cy)) + ((pz - cz) * (pz - cz)))
		if dlen < min_dlen then
			--options.meta=nil
			--options.shift=true
			--spGiveOrderToUnit(unit_id,id,params,options)
			spGiveOrderToUnit(unit_id, id, params, { "shift" })
		else
			spGiveOrderToUnit(unit_id, CMD.INSERT, { insert_pos - 1, id, opt, unpack(params) }, { "alt" })
		end
	end

	-- When we are editing the build order we want to keep same active command after unset by engine
	if id < 0 then
		Spring.SetActiveCommand(Spring.GetCmdDescIndex(id), 1, true, false, options.alt, options.ctrl, false, false)
	end

	return true
end
