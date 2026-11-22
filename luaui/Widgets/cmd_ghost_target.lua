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

local getGhostPosition = Spring.GetGhostPosition
local press
local setGhostHighlight = Spring.SetGhostHighlight
local commands = {
	[CMD.ATTACK] = true,
	[GameCMD.UNIT_SET_TARGET] = true,
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = true,
}

function widget:Initialize()
	if not getGhostPosition then
		widgetHandler:RemoveWidget(self)
	end
end

function widget:MousePress(x, y, button)
	press = nil
	local _, command = Spring.GetActiveCommand()
	if button == 1 and commands[command] and not Spring.IsAboveMiniMap(math.floor(x), math.floor(y)) then
		press = { x = x, y = y, command = command }
	end
	return false
end

---@param x integer
---@param y integer
local function traceTarget(x, y)
	local traceScreenRay = Spring.TraceScreenRay ---@type GhostTraceScreenRay
	return traceScreenRay(x, y, false, false, false, false, 0, true)
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
			local kind, _, ghostAimPos = traceTarget(x, y)
			if kind == "ghost" or kind == "unit" then
				aim = ghostAimPos
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
	if not getGhostPosition or not press or press.command ~= command then
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
	local kind, target, ghostAimPos = traceTarget(x, y)
	---@type CreateCommandParams
	local replacementParams
	if kind == "ghost" and target and target ~= 0 then
		command = command == CMD.ATTACK and GameCMD.GHOST_ATTACK or GameCMD.GHOST_SET_TARGET
		replacementParams = {
			target --[[@as integer]],
		}
	elseif kind == "unit" and ghostAimPos then
		replacementParams = {
			target --[[@as UnitID]],
		}
	else
		return false
	end
	-- Let queue insertion and other command widgets process the resolved point, too.
	if not widgetHandler:CommandNotify(command, replacementParams, options) then
		Spring.GiveOrder(command, replacementParams, options.coded)
	end
	return true
end
