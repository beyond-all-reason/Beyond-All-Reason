local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Loop Select",
		desc = "Selects units inside drawn loop (Hold meta to draw loop)",
		author = "Niobium",
		version = "v1.1",
		date = "Jul 18, 2009",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false,
	}
end

---------------------------------------------------------------------------
-- Variables
---------------------------------------------------------------------------
local fadeRate = 3.0 -- Alpha reduces at fadeRate per second
local conLineAlpha = 0.66 -- Alpha of connecting line when drawing loop
local fillAlpha = 0.06 -- The selection box layers a vignette over its 0.03 fill, the loop has only the fill
local stencilBit = 128 -- Other widgets use the low stencil bits
local growRate = 1 / 30 -- Smartselect update interval while the loop grows
local holdRate = 1 / 15 -- and while it doesn't, to catch units moving in or out
local smartSelectMods = { "idle", "same", "mobile", "any", "all" } -- the ones smartselect reads from its actions

-- Same palette as the selection box (gui_selectionbox.lua)
local styles = {
	normal = { fill = { 1, 1, 1, fillAlpha * 0.8 }, line = { 1, 1, 1 } },
	deselect = { fill = { 1, 0.25, 0.25, fillAlpha }, line = { 1, 0.82, 0.82 } },
	add = { fill = { 0.45, 1, 0.45, fillAlpha }, line = { 0.92, 1, 0.92 } },
}

---------------------------------------------------------------------------
-- Globals
---------------------------------------------------------------------------
local dragging = false -- Obvious
local sNodes = {} -- Loop nodes
local fNodes = {} -- Fading nodes
local fAlpha = 0 -- Fade alpha
local fStyle = styles.normal -- Style of the fading loop
local lx, ly, lz -- Last added pos
local lineWidth = 1.5

-- Smartselect state of the current loop
local ignoredMods = {} -- Smartselect modifiers bound to the loop key
local loopUnits = {} -- Units inside the loop at the last update, as a set
local loopUnitCount = 0
local loopModKeys = -1 ---@type number
local loopNodeCount = 0
local loopTimer = 0.0

-- Loop edges bucketed by z, reused between tests
local bands = {} ---@type table<integer, table<integer, integer>>
local bandCounts = {}

local chobbyInterface

---------------------------------------------------------------------------
-- Speedups
---------------------------------------------------------------------------

local GL_LINE_LOOP = GL.LINE_LOOP
local GL_LINE_STRIP = GL.LINE_STRIP
local GL_TRIANGLE_FAN = GL.TRIANGLE_FAN
local GL_ALWAYS = GL.ALWAYS
local GL_EQUAL = GL.EQUAL
local GL_KEEP = GL.KEEP
local GL_INVERT = GL.INVERT
local GL_ZERO = GL.ZERO

local glDepthTest = gl.DepthTest
local glColor = gl.Color
local glColorMask = gl.ColorMask
local glLineWidth = gl.LineWidth
local glLineStipple = gl.LineStipple
local glStencilTest = gl.StencilTest
local glStencilMask = gl.StencilMask
local glStencilFunc = gl.StencilFunc
local glStencilOp = gl.StencilOp
local glVertex = gl.Vertex
local glBeginEnd = gl.BeginEnd

local spGetMouseState = Spring.GetMouseState
local spGetModKeyState = Spring.GetModKeyState
local spGetActiveCommand = Spring.GetActiveCommand
local spGetActionHotKeys = Spring.GetActionHotKeys
local spGetSpecState = Spring.GetSpectatingState
local spIsGodModeEnabled = Spring.IsGodModeEnabled
local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
local spGetUnitPos = Spring.GetUnitPosition
local spTraceScreenRay = Spring.TraceScreenRay
local spGetSelUnits = Spring.GetSelectedUnits
local spSelUnitArray = Spring.SelectUnitArray

local tremove = table.remove
local mathFloor = math.floor
local mathMin = math.min
local mathMax = math.max

local active = false
-- deselect selection
local deselect = false
-- add to selection
local add = false

---------------------------------------------------------------------------
-- Code
---------------------------------------------------------------------------

local function sVerts(nodes)
	for i = 1, #nodes do
		local node = nodes[i]
		glVertex(node[1], node[2], node[3])
	end
end

local function closingVerts(nodes)
	local first, last = nodes[1], nodes[#nodes]
	glVertex(last[1], last[2], last[3])
	glVertex(first[1], first[2], first[3])
end

-- Even-odd test, the rule the stencil fill draws by, closing the loop from the last node to the first.
-- Edges go into z bands so each unit only tests the edges its row can cross.
local function unitsInLoop(nodes)
	local n = #nodes
	local units = {}
	if n < 3 then
		return units
	end

	local first = nodes[1]
	local minX, maxX, minZ, maxZ = first[1], first[1], first[3], first[3]
	for i = 2, n do
		local x, z = nodes[i][1], nodes[i][3]
		minX, maxX = mathMin(minX, x), mathMax(maxX, x)
		minZ, maxZ = mathMin(minZ, z), mathMax(maxZ, z)
	end
	if maxX <= minX or maxZ <= minZ then
		return units
	end

	local bandCount = mathMax(1, mathMin(64, mathFloor(n / 4)))
	local bandSize = (maxZ - minZ) / bandCount
	for b = 1, bandCount do
		bands[b] = bands[b] or {}
		bandCounts[b] = 0
	end
	local prevZ = nodes[n][3]
	for i = 1, n do
		local z = nodes[i][3]
		if z ~= prevZ then
			local lastBand = mathMin(bandCount, mathFloor((mathMax(z, prevZ) - minZ) / bandSize) + 1)
			for b = mathFloor((mathMin(z, prevZ) - minZ) / bandSize) + 1, lastBand do
				local count = bandCounts[b] + 1
				bandCounts[b] = count
				bands[b][count] = i
			end
		end
		prevZ = z
	end

	local teamFilter = not spGetSpecState() and not spIsGodModeEnabled() and -2 or nil -- -2 = own units
	local candidates = spGetUnitsInRectangle(minX, minZ, maxX, maxZ, teamFilter)
	local count = 0
	for u = 1, #candidates do
		local unitID = candidates[u]
		local ux, _, uz = spGetUnitPos(unitID)
		local b = mathMax(1, mathMin(bandCount, mathFloor((uz - minZ) / bandSize) + 1))
		local band = bands[b]
		local inside = false
		for e = 1, bandCounts[b] do
			local i = band[e]
			local a, p = nodes[i], nodes[i == 1 and n or i - 1]
			local az, pz = a[3], p[3]
			if (az > uz) ~= (pz > uz) and ux < (p[1] - a[1]) * (uz - az) / (pz - az) + a[1] then
				inside = not inside
			end
		end
		if inside then
			count = count + 1
			units[count] = unitID
		end
	end
	return units
end

-- Smartselect modifiers that share a key with the loop (space is also selectbox_idle) are held for every loop
local function loopKeyMods()
	local loopKeys = {}
	for _, key in ipairs(spGetActionHotKeys("selectloop") or {}) do
		loopKeys[key] = true
	end
	local ignored = {}
	for _, mod in ipairs(smartSelectMods) do
		for _, key in ipairs(spGetActionHotKeys("selectbox_" .. mod) or {}) do
			if loopKeys[key] then
				ignored[mod] = true
			end
		end
	end
	return ignored
end

-- Each smartselect call reselects, so only make one when the units or modifier keys changed
local function updateSmartSelect(force)
	local units = unitsInLoop(sNodes)
	local unitCount = #units
	local alt, ctrl, meta, shift = spGetModKeyState()
	local modKeys = (alt and 1 or 0) + (ctrl and 2 or 0) + (meta and 4 or 0) + (shift and 8 or 0)
	local changed = force or modKeys ~= loopModKeys or unitCount ~= loopUnitCount
	local i = 1
	while not changed and i <= unitCount do
		changed = not loopUnits[units[i]]
		i = i + 1
	end
	if not changed then
		return
	end

	loopUnits = {}
	for j = 1, unitCount do
		loopUnits[units[j]] = true
	end
	loopUnitCount = unitCount
	loopModKeys = modKeys
	WG.SmartSelect_SelectUnits(units, ignoredMods)
end

function widget:Update(dt)
	if fAlpha > 0 then
		fAlpha = fAlpha - fadeRate * dt
	end

	if dragging then
		local mx, my = spGetMouseState()
		local _, pos = spTraceScreenRay(mx, my, true)

		if pos then
			local wx, wy, wz = pos[1], pos[2], pos[3]

			if (wx ~= lx) or (wy ~= ly) or (wz ~= lz) then
				sNodes[#sNodes + 1] = { wx, wy, wz }
				lx = wx
				ly = wy
				lz = wz
			end
		end

		if WG.SmartSelect_SelectUnits then
			loopTimer = loopTimer + dt
			if loopTimer >= (#sNodes ~= loopNodeCount and growRate or holdRate) then
				loopTimer = 0.0
				loopNodeCount = #sNodes
				updateSmartSelect(false)
			end
		end
	end
end

local function currentStyle()
	if deselect then
		return styles.deselect
	elseif add then
		return styles.add
	end
	return styles.normal
end

local function drawLoop(nodes, style, alpha, closed)
	-- Even-odd fill through the stencil, the rule MouseRelease selects by, so concave and self-crossing loops fill right
	glColorMask(false)
	glStencilTest(true)
	glStencilMask(stencilBit)
	glStencilFunc(GL_ALWAYS, 0, stencilBit)
	glStencilOp(GL_KEEP, GL_KEEP, GL_INVERT)
	glBeginEnd(GL_TRIANGLE_FAN, sVerts, nodes)

	-- Draw where the bit ended up set, clearing it again
	glColorMask(true)
	glStencilFunc(GL_EQUAL, stencilBit, stencilBit)
	glStencilOp(GL_KEEP, GL_KEEP, GL_ZERO)
	local fill = style.fill
	glColor(fill[1], fill[2], fill[3], fill[4] * alpha)
	glBeginEnd(GL_TRIANGLE_FAN, sVerts, nodes)
	glStencilTest(false)
	glStencilMask(255)
	glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP)

	local primitive = closed and GL_LINE_LOOP or GL_LINE_STRIP
	glLineWidth(lineWidth + 2.5)
	glColor(0, 0, 0, 0.12 * alpha)
	glBeginEnd(primitive, sVerts, nodes)

	glLineStipple("springdefault") -- animated, like the selection box
	glLineWidth(lineWidth)
	local line = style.line
	glColor(line[1], line[2], line[3], alpha)
	glBeginEnd(primitive, sVerts, nodes)
	if not closed then
		glColor(line[1], line[2], line[3], conLineAlpha * alpha)
		glBeginEnd(GL_LINE_STRIP, closingVerts, nodes)
	end
	glLineStipple(false)
end

function widget:RecvLuaMsg(msg)
	if msg:sub(1, 18) == "LobbyOverlayActive" then
		chobbyInterface = (msg:sub(1, 19) == "LobbyOverlayActive1")
	end
end

function widget:ViewResize(vsx, vsy)
	lineWidth = math.max(1.5, vsy / 1080)
end

function widget:DrawWorld()
	if chobbyInterface then
		return
	end

	local drawing = #sNodes > 1
	local fading = (fAlpha > 0) and (#fNodes > 1)
	if not (drawing or fading) then
		return
	end

	glDepthTest(false)

	if drawing then
		drawLoop(sNodes, currentStyle(), 1, false)
	end

	if fading then
		drawLoop(fNodes, fStyle, fAlpha, true)
	end

	glLineWidth(1.0)
	glColor(1, 1, 1, 1)
end

function widget:MousePress(mx, my, mButton)
	-- Only left click
	if mButton ~= 1 then
		return false
	end

	-- Only handle if there is no active command
	local _, actCmdID = spGetActiveCommand()
	if actCmdID ~= nil then
		return false
	end

	-- Only handle if active
	if not active then
		return false
	end

	-- Start dragging
	local _, pos = spTraceScreenRay(mx, my, true)

	if not pos then
		return false
	end

	local wx, wy, wz = pos[1], pos[2], pos[3]
	sNodes[1] = { wx, wy, wz }
	lx = wx
	ly = wy
	lz = wz

	if WG.SmartSelect_SetReference then
		WG.SmartSelect_SetReference()
		ignoredMods = loopKeyMods()
		loopUnits = {}
		loopUnitCount = 0
		loopModKeys = -1
		loopNodeCount = 0
		loopTimer = 0.0
	end

	-- Return true, this gives us the next MouseMove/MouseRelease calls.
	dragging = true
	return true
end

function widget:MouseMove(mx, my)
	local _, pos = spTraceScreenRay(mx, my, true)

	if not pos then
		return
	end

	local wx, wy, wz = pos[1], pos[2], pos[3]
	sNodes[#sNodes + 1] = { wx, wy, wz }
	lx = wx
	ly = wy
	lz = wz
end

-- Selection without smartselect: ctrl inverts, shift adds
local function selectLoopUnits()
	-- Units to select will be an array (Maps are OK too)
	local toSel = unitsInLoop(sNodes)
	local toSelCount = #toSel

	-- Select the units
	if deselect then
		-- ctrl 'inverts' when selecting
		-- For units that we are going to select, if they are already selected, they become unselected
		local selUnits = spGetSelUnits()

		-- Loop over selected units
		for i = 1, #selUnits do
			local uID = selUnits[i]
			local match = false

			-- Check this unit against poly units
			for j = 1, toSelCount do
				if toSel[j] == uID then
					match = j
					break
				end
			end

			if match then
				-- Selected unit is also in poly
				-- So we shouldn't select it
				-- Remove from toSel
				tremove(toSel, match)
				toSelCount = toSelCount - 1
			else
				toSelCount = toSelCount + 1
				toSel[toSelCount] = uID
			end
		end
	else
		if add then
			-- Easy, add units we already have selected, unless they are in poly
			-- We probably don't want to have duplicates in what we select
			local selUnits = spGetSelUnits()

			for i = 1, #selUnits do
				local uID = selUnits[i]
				local inPoly = false

				-- Check this unit against poly units
				for j = 1, toSelCount do
					if toSel[j] == uID then
						inPoly = true
						break
					end
				end

				-- Add if wasn't found
				if not inPoly then
					toSelCount = toSelCount + 1
					toSel[toSelCount] = uID
				end
			end
		end
	end

	-- Modifiers handled, select units
	spSelUnitArray(toSel)
end

function widget:MouseRelease(mx, my)
	-- Add final node (If different)
	local _, pos = spTraceScreenRay(mx, my, true)

	if pos then
		local wx, wy, wz = pos[1], pos[2], pos[3]
		if (wx ~= lx) or (wy ~= ly) or (wz ~= lz) then
			sNodes[#sNodes + 1] = { wx, wy, wz }
			lx = wx
			ly = wy
			lz = wz
		end
	end

	if #sNodes < 2 then
		-- Not enough nodes
		-- Reset nodes
		sNodes = {}
		dragging = false
		if WG.SmartSelect_ClearReference then
			WG.SmartSelect_ClearReference()
		end
		return
	end

	if WG.SmartSelect_SelectUnits then
		-- Smartselect filters the units and handles ctrl/shift like for a selection box
		updateSmartSelect(true)
		WG.SmartSelect_ClearReference()
	else
		selectLoopUnits()
	end

	-- Reset nodes
	fNodes = sNodes
	fStyle = currentStyle()
	fAlpha = 1.0
	sNodes = {}
	dragging = false
end

local function setActive()
	active = true
end

local function unsetActive()
	active = false
end

local function setDeselect()
	deselect = true
end

local function unsetDeselect()
	deselect = false
end

local function setAdd()
	add = true
end

local function unsetAdd()
	add = false
end

function widget:Initialize()
	widget:ViewResize(Spring.GetViewGeometry())
	widgetHandler:AddAction("selectloop", setActive, nil, "p")
	widgetHandler:AddAction("selectloop", unsetActive, nil, "r")
	-- The keybind files bind selectloop_invert, keep the old name for custom uikeys
	widgetHandler:AddAction("selectloop_invert", setDeselect, nil, "p")
	widgetHandler:AddAction("selectloop_invert", unsetDeselect, nil, "r")
	widgetHandler:AddAction("selectloop_deselect", setDeselect, nil, "p")
	widgetHandler:AddAction("selectloop_deselect", unsetDeselect, nil, "r")
	widgetHandler:AddAction("selectloop_add", setAdd, nil, "p")
	widgetHandler:AddAction("selectloop_add", unsetAdd, nil, "r")
end

---------------------------------------------------------------------------
