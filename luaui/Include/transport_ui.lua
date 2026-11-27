-- Helpers the tractor beam transport widgets share.
local TransportUI = {}

-- shift, flipped when the invert queue key option is on
function TransportUI.shiftHeld()
	local _, _, _, shift = Spring.GetModKeyState()
	if Spring.GetInvertQueueKey() then
		return not shift
	end
	return shift
end

---@return number? x
---@return number? y
---@return number? z
function TransportUI.cursorGround(mx, my)
	local _, pos = Spring.TraceScreenRay(mx, my, true)
	if pos and pos[1] then
		return pos[1], pos[2], pos[3]
	end
end

-- "active": one of these commands is armed; "default": a right click would give one
---@param commands table<integer, true>
---@return "active"|"default"|nil
function TransportUI.commandMode(commands)
	local _, activeCmdID = Spring.GetActiveCommand()
	if activeCmdID then
		return commands[activeCmdID] and "active" or nil
	end
	local _, defaultCmdID = Spring.GetDefaultCommand()
	return defaultCmdID and commands[defaultCmdID] and "default" or nil
end

-- a preview toggle from Transport Settings; on when that widget is off
---@param key string
function TransportUI.settingOn(key)
	local settings = WG.TransportSettings
	return not settings or settings[key] ~= false
end

---@param api table WG.TransportAPI
---@param units integer[]
---@return integer[]
function TransportUI.tractorTransports(api, units)
	local transports = {}
	for i = 1, #units do
		if api.IsTractorTransport(units[i]) then
			transports[#transports + 1] = units[i]
		end
	end
	return transports
end

-- an X lying on the ground, for GL.LINES
function TransportUI.crossVertices(x, y, z, size)
	gl.Vertex(x - size, y, z - size)
	gl.Vertex(x + size, y, z + size)
	gl.Vertex(x - size, y, z + size)
	gl.Vertex(x + size, y, z - size)
end

return TransportUI
