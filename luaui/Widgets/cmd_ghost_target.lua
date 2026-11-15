local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Ghost Target",
		desc = "Aim single attack and set-target clicks at the last observed ghost aimpoint",
		author = "BAR contributors",
		license = "GNU GPL, v2 or later",
		layer = 10001, -- Observe clicks before CustomFormations2; resolve before CommandInsert.
		handler = true,
		enabled = true,
	}
end

local keepHeight = CMD.OPT_KEEP_HEIGHT
local press
local setGhostHighlight = Spring.SetGhostHighlight
local commands = {
	[CMD.ATTACK] = true,
	[GameCMD.UNIT_SET_TARGET] = true,
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = true,
}

function widget:Initialize()
	if not keepHeight then
		widgetHandler:RemoveWidget(self)
	end
end

function widget:MousePress(x, y, button)
	press = nil
	local _, command = Spring.GetActiveCommand()
	if button == 1 and commands[command] and not Spring.IsAboveMiniMap(x, y) then
		press = { x = x, y = y, command = command }
	end
	return false
end

local function traceTarget(x, y)
	return Spring.TraceScreenRay(x, y, false, false, false, false, 0, true)
end

function widget:Shutdown()
	if setGhostHighlight then
		setGhostHighlight()
	end
end

function widget:Update()
	if setGhostHighlight then
		local x, y, left, middle, _, offscreen, panning = Spring.GetMouseState()
		local _, command = Spring.GetActiveCommand()
		local aim
		if
			commands[command]
			and not (left or middle or offscreen or panning)
			and not Spring.IsGUIHidden()
			and not Spring.IsAboveMiniMap(x, y)
			and widgetHandler:ModalAllows(self)
		then
			local kind, position = traceTarget(x, y)
			if kind == "ghost" then
				aim = position
			end
		end
		if aim then
			setGhostHighlight(aim[1], aim[2], aim[3])
		else
			setGhostHighlight()
		end
	end
	if not press then
		return
	end
	local x, y, left = Spring.GetMouseState()
	local threshold = Spring.GetConfigInt("MouseDragCircleCommandThreshold", 4)
	if not left or (x - press.x) ^ 2 + (y - press.y) ^ 2 > threshold ^ 2 then
		press = nil
	end
end

function widget:CommandNotify(command, params, options)
	if not press or press.command ~= command then
		return false
	end
	local click = press
	press = nil
	if options.internal or (#params ~= 3 and not (#params == 4 and params[4] == 0)) then
		return false
	end
	local x, y = Spring.GetMouseState()
	local threshold = Spring.GetConfigInt("MouseDragCircleCommandThreshold", 4)
	if Spring.IsAboveMiniMap(x, y) or (x - click.x) ^ 2 + (y - click.y) ^ 2 > threshold ^ 2 then
		return false
	end
	local kind, aim = traceTarget(x, y)
	if kind ~= "ghost" then
		return false
	end

	local replacementOptions = table.copy(options)
	replacementOptions.keepheight = true
	replacementOptions.coded = math.bit_or(options.coded or 0, keepHeight)
	-- Let queue insertion and other command widgets process the resolved point, too.
	if not widgetHandler:CommandNotify(command, aim, replacementOptions) then
		Spring.GiveOrder(command, aim, replacementOptions.coded)
	end
	return true
end
