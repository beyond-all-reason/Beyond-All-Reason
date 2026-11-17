local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Selectionbox",
		desc = "Customizes the appearance of the selection box rectangle",
		author = "Floris",
		date = "September 2024",
		license = "GNU GPL, v2 or later",
		layer = 999998, -- alone on its layer: toggling DrawScreen must not reorder it against other widgets
		enabled = true,
	}
end

local spGetSelectionBox = Spring.GetSelectionBox
local spGetModKeyState = Spring.GetModKeyState
local spGetMouseState = Spring.GetMouseState
local spGetMiniMapGeometry = Spring.GetMiniMapGeometry

local glColor = gl.Color
local glRect = gl.Rect
local glTexRect = gl.TexRect
local glTexture = gl.Texture
local glPolygonMode = gl.PolygonMode
local glLineWidth = gl.LineWidth
local glLineStipple = gl.LineStipple
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local GL_FRONT_AND_BACK = GL.FRONT_AND_BACK
local GL_LINE = GL.LINE
local GL_FILL = GL.FILL
local GL_LINE_LOOP = GL.LINE_LOOP

local mathMax = math.max
local mathMin = math.min

local vignetteTexture = ":n:" .. LUAUI_DIRNAME .. "Images/vignette.dds"

local lineWidth = 1.5

-- Optional: Enable colored selection box based on modifier keys
local coloredModifierKeys = true -- Set to false to always use white selection box

-- Update/DrawScreen only run from a left press until its release
local tracking = false

-- Track minimap selection
local minimapSelectionActive = false
local minimapSelectionStart = { x = 0, y = 0 }
local minimapSelectionEnd = { x = 0, y = 0 }
local minimapGeometryCache = { x = 0, y = 0, w = 0, h = 0 }

local loopX1, loopY1, loopX2, loopY2 = 0.0, 0.0, 0.0, 0.0
local function minimapBoxVertices()
	glVertex(loopX1, loopY1)
	glVertex(loopX2, loopY1)
	glVertex(loopX2, loopY2)
	glVertex(loopX1, loopY2)
end

local function setTracking(active)
	if active == tracking then
		return
	end
	tracking = active
	if active then
		widgetHandler:UpdateCallIn("Update")
		widgetHandler:UpdateCallIn("DrawScreen")
	else
		widgetHandler:RemoveCallIn("Update")
		widgetHandler:RemoveCallIn("DrawScreen")
	end
end

local function setMinimapSelectionActive(active)
	if active == minimapSelectionActive then
		return
	end
	minimapSelectionActive = active
	if active then
		widgetHandler:UpdateCallIn("DrawInMiniMap")
	else
		widgetHandler:RemoveCallIn("DrawInMiniMap")
	end
end

local function startMinimapSelection(x, y, mmX, mmY, mmW, mmH)
	setMinimapSelectionActive(true)
	minimapSelectionStart.x = x
	minimapSelectionStart.y = y
	minimapSelectionEnd.x = x
	minimapSelectionEnd.y = y
	-- Cache the geometry
	minimapGeometryCache.x = mmX
	minimapGeometryCache.y = mmY
	minimapGeometryCache.w = mmW
	minimapGeometryCache.h = mmH
end

local function leftClickMovesCamera()
	local minimap = WG.minimap
	return minimap and minimap.getLeftClickMove and minimap.getLeftClickMove()
end

function widget:ViewResize(vsx, vsy)
	lineWidth = mathMax(1.5, vsy / 1080)
end

function widget:Initialize()
	widget:ViewResize(Spring.GetViewGeometry())
	-- Disable engine's selection box rendering completely by setting line width to 0
	-- and making the color transparent

	Spring.LoadCmdColorsConfig("mouseBoxLineWidth 0")

	widgetHandler:RemoveCallIn("Update")
	widgetHandler:RemoveCallIn("DrawScreen")
	widgetHandler:RemoveCallIn("DrawInMiniMap")
	local _, _, leftPressed = spGetMouseState()
	if leftPressed then
		setTracking(true)
	end
end

function widget:Shutdown()
	-- Restore engine's default selection box
	Spring.LoadCmdColorsConfig("mouseBoxLineWidth 1.5")
end

function widget:DrawScreen() -- This blurs the UI elements obscured by other UI elements (only unit stats so far!)
	local x1, y1, x2, y2 = spGetSelectionBox()
	if y2 then
		-- Get modifier key states
		local alt, ctrl, meta, shift = spGetModKeyState()

		local a = 0.03
		-- Determine color based on modifier keys (if enabled)
		if coloredModifierKeys and ctrl then
			-- Brighter red when ctrl is held (with or without other keys)
			glColor(1, 0.25, 0.25, a)
		elseif coloredModifierKeys and shift then
			-- Bright green when only shift is held
			glColor(0.45, 1, 0.45, a)
		else
			-- White for normal selection
			glColor(1, 1, 1, a * 0.8)
		end
		-- selection box background
		glRect(x1, y1, x2, y2)
		-- selection box background vignette
		glColor(1, 1, 1, 0.03)
		glTexture(vignetteTexture)
		glTexRect(x1, y1, x2, y2)
		glTexture(false)

		-- black selection outline
		glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)
		glLineWidth(lineWidth + 2.5)
		glColor(0, 0, 0, 0.12)
		glRect(x1, y1, x2, y2)

		-- colored selection outline based on modifier keys
		glLineStipple(true) -- animated stipplelines!
		glLineWidth(lineWidth)

		-- Determine color based on modifier keys (if enabled)
		if coloredModifierKeys and ctrl then
			-- Brighter red when ctrl is held (with or without other keys)
			glColor(1, 0.82, 0.82, 1)
		elseif coloredModifierKeys and shift then
			-- Bright green when only shift is held
			glColor(0.92, 1, 0.92, 1)
		else
			-- White for normal selection
			glColor(1, 1, 1, 1)
		end

		glRect(x1, y1, x2, y2)
		glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
		glLineStipple(false)
	end
end

function widget:MousePress(x, y, button)
	if button ~= 1 then
		return false
	end
	-- Every engine selection box starts with a left press no widget claimed, so this one is seen
	setTracking(true)

	-- Don't track selection if minimap left-click-move is enabled
	if leftClickMovesCamera() then
		return false
	end

	-- Check if click is on minimap
	local mmX, mmY, mmW, mmH, minimized, maximized = spGetMiniMapGeometry()
	if not mmX or minimized or maximized then
		return false
	end

	-- mmY is bottom edge, top edge is mmY + mmH
	if x >= mmX and x <= mmX + mmW and y >= mmY and y <= mmY + mmH then
		-- Click is on minimap, start tracking selection
		startMinimapSelection(x, y, mmX, mmY, mmW, mmH)
	end

	return false
end

function widget:Update()
	local mx, my, leftPressed = spGetMouseState()

	if not leftPressed then
		-- Mouse released
		setMinimapSelectionActive(false)
		setTracking(false)
		return
	end

	-- Don't track selection if minimap left-click-move is enabled
	if leftClickMovesCamera() then
		setMinimapSelectionActive(false)
		return
	end

	local mmX, mmY, mmW, mmH, minimized, maximized = spGetMiniMapGeometry()
	if mmX and not minimized and not maximized then
		-- mmY is the bottom edge of the minimap (distance from screen bottom)
		-- Top edge is at mmY + mmH
		local minimapBottom = mmY
		local minimapTop = mmY + mmH

		-- Check if mouse is within minimap bounds
		if mx >= mmX and mx <= mmX + mmW and my >= minimapBottom and my <= minimapTop then
			if not minimapSelectionActive then
				-- Start new selection
				startMinimapSelection(mx, my, mmX, mmY, mmW, mmH)
			end
			-- Update end position (not clamped yet, will clamp in Draw)
			minimapSelectionEnd.x = mx
			minimapSelectionEnd.y = my
		elseif minimapSelectionActive then
			-- Mouse left minimap while dragging, clamp to minimap bounds
			minimapSelectionEnd.x = mathMax(mmX, mathMin(mmX + mmW, mx))
			minimapSelectionEnd.y = mathMax(minimapBottom, mathMin(minimapTop, my))
		end
	end
end

function widget:DrawInMiniMap(minimapWidth, minimapHeight)
	-- Skip if PIP minimap replacement is active (it handles its own selection box)
	if WG.minimap and WG.minimap.isPipMinimapActive and WG.minimap.isPipMinimapActive() then
		return
	end

	-- Draw selection for minimap-tracked selection
	if not minimapSelectionActive then
		return
	end

	-- Don't draw if minimap left-click-move is enabled
	if leftClickMovesCamera() then
		return
	end

	-- Use cached geometry from when selection started
	local mmX = minimapGeometryCache.x
	local mmY = minimapGeometryCache.y
	local mmW = minimapGeometryCache.w
	local mmH = minimapGeometryCache.h

	if mmW == 0 or mmH == 0 then
		return
	end

	-- Get modifier key states
	local alt, ctrl, meta, shift = spGetModKeyState()

	-- Validate that both start and end are within minimap bounds
	local x1, y1 = minimapSelectionStart.x, minimapSelectionStart.y
	local x2, y2 = minimapSelectionEnd.x, minimapSelectionEnd.y

	-- mmY is bottom edge, top edge is mmY + mmH
	local minimapBottom = mmY
	local minimapTop = mmY + mmH

	-- Clamp coordinates to minimap bounds (in case mouse went outside)
	x1 = mathMax(mmX, mathMin(mmX + mmW, x1))
	y1 = mathMax(minimapBottom, mathMin(minimapTop, y1))
	x2 = mathMax(mmX, mathMin(mmX + mmW, x2))
	y2 = mathMax(minimapBottom, mathMin(minimapTop, y2)) -- Convert screen coordinates to minimap pixel coordinates
	local mx1 = ((x1 - mmX) / mmW) * minimapWidth
	local my1 = ((y1 - mmY) / mmH) * minimapHeight
	local mx2 = ((x2 - mmX) / mmW) * minimapWidth
	local my2 = ((y2 - mmY) / mmH) * minimapHeight

	-- Ensure proper ordering (x1 < x2, y1 < y2)
	if mx1 > mx2 then
		mx1, mx2 = mx2, mx1
	end
	if my1 > my2 then
		my1, my2 = my2, my1
	end

	local width = mx2 - mx1
	local height = my2 - my1

	-- Skip if box is too small
	if width < 1 or height < 1 then
		return
	end -- Draw filled rectangle with transparency
	local a = 0.08
	if ctrl then
		glColor(1, 0.25, 0.25, a)
	elseif shift then
		glColor(0.45, 1, 0.45, a)
	else
		glColor(1, 1, 1, a * 0.8)
	end
	glRect(mx1, my1, mx2, my2)

	-- Draw stippled outline
	glLineStipple(true)
	glLineWidth(2.0)
	if ctrl then
		glColor(1, 0.82, 0.82, 1)
	elseif shift then
		glColor(0.92, 1, 0.92, 1)
	else
		glColor(1, 1, 1, 1)
	end
	loopX1, loopY1, loopX2, loopY2 = mx1, my1, mx2, my2
	glBeginEnd(GL_LINE_LOOP, minimapBoxVertices)
	glLineStipple(false)

	glLineWidth(1.0)
	glColor(1, 1, 1, 1)
end
