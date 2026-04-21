local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Metal Brush",
		desc = "Paint and stamp metal deposits on the map. Requires /cheat.",
		author = "BARb",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local MSG_PAINT = "$metal_paint$"
local MSG_STAMP = "$metal_stamp$"
local MSG_CLEAR = "$metal_clear$"
local MSG_LOAD  = "$metal_load$"
local MSG_UNDO  = "$metal_undo$"
local MSG_REDO  = "$metal_redo$"
local CHEAT_TAG = "$c$"

local function SendLuaRulesMsg(header, payload)
	local tag = Spring.IsCheatingEnabled() and CHEAT_TAG or ""
	Spring.SendLuaRulesMsg(header .. tag .. payload)
end

local GetMouseState = Spring.GetMouseState
local TraceScreenRay = Spring.TraceScreenRay
local GetGroundHeight = Spring.GetGroundHeight
local GetMetalAmount = Spring.GetMetalAmount
local GetMetalMapSize = Spring.GetMetalMapSize
local WorldToScreenCoords = Spring.WorldToScreenCoords
local Echo = Spring.Echo
local IsCheatingEnabled = Spring.IsCheatingEnabled

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glPolygonOffset = gl.PolygonOffset
local glText = gl.Text
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_LINES = GL.LINES
local GL_QUADS = GL.QUADS

local floor = math.floor
local max = math.max
local min = math.min
local cos = math.cos
local sin = math.sin
local abs = math.abs
local pi = math.pi
local sqrt = math.sqrt
local format = string.format

local METAL_SQ = Game.metalMapSquareSize or 16
local CIRCLE_SEGMENTS = 48
local UPDATE_INTERVAL = 0.05
local MIN_METAL_VALUE = 0.01
local MAX_METAL_VALUE = 50.0
local DEFAULT_METAL_VALUE = 2.0
local DEFAULT_RADIUS = 32
local SAVE_DIR = "Terraform Brush/MetalMaps/"

-- State
local active = false
local subMode = "paint"       -- "paint" or "stamp"
local metalValue = DEFAULT_METAL_VALUE
local painting = false
local paintButton = 0         -- 1 = LMB (raise), 3 = RMB (lower/erase)
local lastPaintTime = 0

local function getSharedState()
	if WG.TerraformBrush then
		local st = WG.TerraformBrush.getState()
		return {
			radius = st.radius or DEFAULT_RADIUS,
			shape = st.shape or "circle",
			rotationDeg = st.rotationDeg or 0,
			curve = st.curve or 1.0,
			intensity = st.intensity or 1.0,
		}
	end
	return {
		radius = DEFAULT_RADIUS,
		shape = "circle",
		rotationDeg = 0,
		curve = 1.0,
		intensity = 1.0,
	}
end

local function getWorldPos()
	local mx, my = GetMouseState()
	local kind, pos = TraceScreenRay(mx, my, true)
	if kind == "ground" then
		return pos[1], pos[3]
	end
	return nil, nil
end

local function sendPaintMessage(worldX, worldZ)
	local ss = getSharedState()
	local direction = (paintButton == 1) and 1 or -1
	local tb = WG.TerraformBrush
	local positions
	if tb and tb.snapWorld then
		worldX, worldZ = tb.snapWorld(worldX, worldZ, ss.rotationDeg)
	end
	if tb and tb.getSymmetricPositions then
		positions = tb.getSymmetricPositions(worldX, worldZ, ss.rotationDeg)
	end
	if not positions or #positions == 0 then
		positions = { { x = worldX, z = worldZ, rot = ss.rotationDeg } }
	end
	for i = 1, #positions do
		local p = positions[i]
		local payload = direction .. " "
			.. floor(p.x) .. " "
			.. floor(p.z) .. " "
			.. ss.radius .. " "
			.. ss.shape .. " "
			.. (p.rot or ss.rotationDeg) .. " "
			.. format("%.1f", ss.curve) .. " "
			.. format("%.1f", ss.intensity) .. " "
			.. format("%.2f", metalValue)
		SendLuaRulesMsg(MSG_PAINT, payload)
	end
end

local function sendStampMessage(worldX, worldZ)
	local ss = getSharedState()
	local direction = (paintButton == 3) and -1 or 1
	local tb = WG.TerraformBrush
	local positions
	if tb and tb.snapWorld then
		worldX, worldZ = tb.snapWorld(worldX, worldZ, ss.rotationDeg)
	end
	if tb and tb.getSymmetricPositions then
		positions = tb.getSymmetricPositions(worldX, worldZ, ss.rotationDeg)
	end
	if not positions or #positions == 0 then
		positions = { { x = worldX, z = worldZ, rot = ss.rotationDeg } }
	end
	for i = 1, #positions do
		local p = positions[i]
		local payload = floor(p.x) .. " "
			.. floor(p.z) .. " "
			.. ss.radius .. " "
			.. format("%.2f", metalValue) .. " "
			.. ss.shape .. " "
			.. (p.rot or ss.rotationDeg) .. " "
			.. direction
		SendLuaRulesMsg(MSG_STAMP, payload)
	end
end

-- ============================================================
-- Drawing
-- ============================================================

local function drawShapeOutline(worldX, worldZ, radius, shape, angleDeg)
	if shape == "circle" then
		glBeginEnd(GL_LINE_LOOP, function()
			for i = 0, CIRCLE_SEGMENTS - 1 do
				local angle = (i / CIRCLE_SEGMENTS) * 2 * pi
				local x = worldX + radius * cos(angle)
				local z = worldZ + radius * sin(angle)
				glVertex(x, GetGroundHeight(x, z) + 2, z)
			end
		end)
	else
		local sides = 4
		if shape == "hexagon" then sides = 6
		elseif shape == "octagon" then sides = 8 end
		local angleRad = (angleDeg or 0) * pi / 180
		local c, s = cos(angleRad), sin(angleRad)
		glBeginEnd(GL_LINE_LOOP, function()
			for i = 0, sides - 1 do
				local a = (i / sides) * 2 * pi
				local dx0, dz0 = radius * cos(a), radius * sin(a)
				local dx = dx0 * c - dz0 * s
				local dz = dx0 * s + dz0 * c
				local x, z = worldX + dx, worldZ + dz
				glVertex(x, GetGroundHeight(x, z) + 2, z)
			end
		end)
	end
end

local function drawMetalOverlay(worldX, worldZ, radius)
	local halfSq = METAL_SQ * 0.5
	local mxMin = max(0, floor((worldX - radius - METAL_SQ) / METAL_SQ))
	local mxMax = floor((worldX + radius + METAL_SQ) / METAL_SQ)
	local mzMin = max(0, floor((worldZ - radius - METAL_SQ) / METAL_SQ))
	local mzMax = floor((worldZ + radius + METAL_SQ) / METAL_SQ)

	local mmX, mmZ = GetMetalMapSize()
	mxMax = min(mxMax, mmX - 1)
	mzMax = min(mzMax, mmZ - 1)

	-- Cap to prevent excessive draw calls
	if (mxMax - mxMin + 1) * (mzMax - mzMin + 1) > 4000 then return end

	glPolygonOffset(-2, -2)
	for mz = mzMin, mzMax do
		local wz = mz * METAL_SQ + halfSq
		for mx = mxMin, mxMax do
			local amount = GetMetalAmount(mx, mz)
			if amount > 0.01 then
				local wx = mx * METAL_SQ + halfSq
				local brightness = min(1.0, amount / 120)
				glColor(0.1, 0.4 + brightness * 0.6, 0.1, 0.35 + brightness * 0.3)
				local y = GetGroundHeight(wx, wz) + 0.5
				glBeginEnd(GL_QUADS, function()
					glVertex(wx - halfSq, y, wz - halfSq)
					glVertex(wx + halfSq, y, wz - halfSq)
					glVertex(wx + halfSq, y, wz + halfSq)
					glVertex(wx - halfSq, y, wz + halfSq)
				end)
			end
		end
	end
	glPolygonOffset(false)
end

local function drawCursorInfo(worldX, worldZ)
	local mx = floor(worldX / METAL_SQ)
	local mz = floor(worldZ / METAL_SQ)
	local currentMetal = GetMetalAmount(mx, mz)
	local sx, sy = WorldToScreenCoords(worldX, GetGroundHeight(worldX, worldZ), worldZ)

	local text
	if subMode == "stamp" then
		text = format("STAMP: %.1f  [cur: %.1f]", metalValue, currentMetal)
	else
		text = format("Metal: %.1f  [cur: %.1f]", metalValue, currentMetal)
	end

	glColor(1, 1, 1, 0.9)
	glText(text, sx, sy + 20, 13, "co")
end

-- ============================================================
-- Metal Map Save
-- ============================================================

local function saveMetalMap()
	Spring.CreateDir(SAVE_DIR)
	local mmX, mmZ = GetMetalMapSize()
	local mapName = Game.mapName or "unknown"
	local filename = SAVE_DIR .. mapName .. "_metalmap.lua"

	local lines = {}
	lines[#lines + 1] = "-- Metal map data for " .. mapName
	lines[#lines + 1] = "-- Generated by Metal Brush"
	lines[#lines + 1] = "-- Metalmap size: " .. mmX .. " x " .. mmZ .. "  squareSize: " .. METAL_SQ
	lines[#lines + 1] = "return {"
	lines[#lines + 1] = "  squareSize = " .. METAL_SQ .. ","
	lines[#lines + 1] = "  width = " .. mmX .. ","
	lines[#lines + 1] = "  height = " .. mmZ .. ","
	lines[#lines + 1] = "  spots = {"

	local spotCount = 0
	for mz = 0, mmZ - 1 do
		for mx = 0, mmX - 1 do
			local amount = GetMetalAmount(mx, mz)
			if amount > 0.001 then
				local wx = mx * METAL_SQ + METAL_SQ * 0.5
				local wz = mz * METAL_SQ + METAL_SQ * 0.5
				lines[#lines + 1] = "    {x=" .. format("%.0f", wx)
					.. ",z=" .. format("%.0f", wz)
					.. ",mx=" .. mx .. ",mz=" .. mz
					.. ",amount=" .. format("%.3f", amount) .. "},"
				spotCount = spotCount + 1
			end
		end
	end

	lines[#lines + 1] = "  },"
	lines[#lines + 1] = "}"

	local content = table.concat(lines, "\n")
	local file = io.open(filename, "w")
	if file then
		file:write(content)
		file:close()
		Echo("[Metal Brush] Saved " .. spotCount .. " metal pixels to: " .. filename)
	else
		Echo("[Metal Brush] ERROR: Could not save to " .. filename)
	end
end

local function loadMetalMap()
	local mapName = Game.mapName or "unknown"
	local filename = SAVE_DIR .. mapName .. "_metalmap.lua"

	local chunk, err = loadfile(filename)
	if not chunk then
		Echo("[Metal Brush] No saved metal map found: " .. filename)
		return
	end

	local ok, data = pcall(chunk)
	if not ok or type(data) ~= "table" or not data.spots then
		Echo("[Metal Brush] ERROR: Invalid metal map file: " .. filename)
		return
	end

	-- First clear everything
	SendLuaRulesMsg(MSG_CLEAR, "")

	-- Then load spots in batches to avoid message size limits
	local BATCH = 100
	local spots = data.spots
	local parts = {}
	local batchCount = 0

	for i = 1, #spots do
		local s = spots[i]
		if s.mx and s.mz and s.amount then
			parts[#parts + 1] = s.mx
			parts[#parts + 1] = s.mz
			parts[#parts + 1] = format("%.3f", s.amount)
			batchCount = batchCount + 1

			if batchCount >= BATCH then
				SendLuaRulesMsg(MSG_LOAD, table.concat(parts, " "))
				parts = {}
				batchCount = 0
			end
		end
	end

	if batchCount > 0 then
		SendLuaRulesMsg(MSG_LOAD, table.concat(parts, " "))
	end

	Echo("[Metal Brush] Loaded " .. #spots .. " metal spots from: " .. filename)
end

local function clearMetalMap()
	SendLuaRulesMsg(MSG_CLEAR, "")
	Echo("[Metal Brush] Cleared all metal from map")
end

-- ============================================================
-- State Management & WG Interface
-- ============================================================

local function activate(mode)
	active = true
	subMode = mode or "paint"
	painting = false
	Echo("[Metal Brush] Activated: " .. subMode:upper() .. " | Metal Value: " .. metalValue)
end

local function deactivate()
	if active then
		Echo("[Metal Brush] Deactivated")
	end
	active = false
	painting = false
	paintButton = 0
end

local function setSubMode(mode)
	subMode = mode or "paint"
end

local function setMetalValue(v)
	metalValue = max(MIN_METAL_VALUE, min(MAX_METAL_VALUE, v))
end

local function getState()
	return {
		active = active,
		subMode = subMode,
		metalValue = metalValue,
	}
end

-- ============================================================
-- Widget Callbacks
-- ============================================================

function widget:Initialize()
	WG.MetalBrush = {
		activate = activate,
		deactivate = deactivate,
		getState = getState,
		setSubMode = setSubMode,
		setMetalValue = setMetalValue,
		saveMetalMap = saveMetalMap,
		loadMetalMap = loadMetalMap,
		clearMetalMap = clearMetalMap,
		undo = function() SendLuaRulesMsg(MSG_UNDO, "") end,
		redo = function() SendLuaRulesMsg(MSG_REDO, "") end,
	}
end

function widget:Shutdown()
	WG.MetalBrush = nil
end

function widget:IsAbove(x, y)
	return false
end

function widget:MousePress(mx, my, button)
	if not active then return false end
	if not IsCheatingEnabled() then return false end

	-- Defer to measure tool when active so metal paint doesn't consume the click
	local tb = WG.TerraformBrush
	if tb and tb.getState then
		local st = tb.getState()
		if st and st.measureActive then return false end
		-- Defer to symmetry origin placement / drag-grab so terraform can handle it
		if st and st.symmetryActive then
			if st.symmetryPlacingOrigin or st.symmetryHoveringOrigin or st.symmetryDraggingOrigin then
				return false
			end
		end
	end

	local worldX, worldZ = getWorldPos()
	if not worldX then return false end

	if button == 1 or button == 3 then
		paintButton = button
		if subMode == "stamp" then
			sendStampMessage(worldX, worldZ)
			return true
		else
			painting = true
			lastPaintTime = 0
			sendPaintMessage(worldX, worldZ)
			return true
		end
	end

	return false
end

function widget:MouseRelease(mx, my, button)
	if painting and button == paintButton then
		painting = false
		paintButton = 0
	end
end

function widget:MouseWheel(up, value)
	if not active then return false end
	local alt, ctrl, _, shift = Spring.GetModKeyState()
	local space = Spring.GetKeyState(0x20)

	-- Space+scroll: metalValue (counterpart of intensity)
	if space then
		local step = 0.1
		if metalValue > 10.0 then step = 1.0
		elseif metalValue > 5.0 then step = 0.5
		end
		if up then
			metalValue = min(MAX_METAL_VALUE, metalValue + step)
		else
			metalValue = max(MIN_METAL_VALUE, metalValue - step)
		end
		Echo("[Metal Brush] Metal value: " .. format("%.2f", metalValue))
		return true
	end

	local tb = WG.TerraformBrush
	if not tb then return false end
	local st = tb.getState()

	-- Ctrl+Alt+scroll: length
	if ctrl and alt then
		local ls = (st.lengthScale or 1.0) + (up and 0.1 or -0.1)
		tb.setLengthScale(max(0.1, ls))
		return true
	end

	-- Ctrl+scroll: size
	if ctrl then
		local r = (st.radius or DEFAULT_RADIUS) + (up and 8 or -8)
		tb.setRadius(max(8, r))
		return true
	end

	-- Alt+scroll: rotation
	if alt then
		local rot = ((st.rotationDeg or 0) + (up and 3 or -3)) % 360
		tb.setRotation(rot)
		return true
	end

	-- Shift+scroll: falloff (curve)
	if shift then
		local c = (st.curve or 1.0) + (up and 0.1 or -0.1)
		c = max(0.1, min(5.0, c))
		c = floor(c * 10 + 0.5) / 10
		tb.setCurve(c)
		return true
	end

	return false
end

function widget:Update(dt)
	if not active or not painting then return end

	lastPaintTime = lastPaintTime + dt
	if lastPaintTime < UPDATE_INTERVAL then return end
	lastPaintTime = 0

	local worldX, worldZ = getWorldPos()
	if not worldX then return end

	sendPaintMessage(worldX, worldZ)
end

function widget:DrawWorld()
	if not active then return end

	local worldX, worldZ = getWorldPos()
	if not worldX then return end

	local ss = getSharedState()

	-- Draw metal density overlay near cursor
	drawMetalOverlay(worldX, worldZ, ss.radius)

	-- Draw brush outline
	local colorR, colorG, colorB = 0.2, 1.0, 0.2
	if subMode == "stamp" then
		if paintButton == 3 then
			colorR, colorG, colorB = 1.0, 0.3, 0.0
		else
			colorR, colorG, colorB = 1.0, 0.85, 0.0
		end
	elseif paintButton == 3 then
		colorR, colorG, colorB = 1.0, 0.3, 0.3
	end
	glColor(colorR, colorG, colorB, 0.85)
	glLineWidth(2)
	drawShapeOutline(worldX, worldZ, ss.radius, ss.shape, ss.rotationDeg)

	-- Draw center cross
	local groundY = GetGroundHeight(worldX, worldZ)
	glColor(1, 1, 1, 0.5)
	glBeginEnd(GL_LINES, function()
		glVertex(worldX - 8, groundY + 2, worldZ)
		glVertex(worldX + 8, groundY + 2, worldZ)
		glVertex(worldX, groundY + 2, worldZ - 8)
		glVertex(worldX, groundY + 2, worldZ + 8)
	end)

	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

function widget:DrawScreen()
	if not active then return end

	local worldX, worldZ = getWorldPos()
	if not worldX then return end

	drawCursorInfo(worldX, worldZ)
end
